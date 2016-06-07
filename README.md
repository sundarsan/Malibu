# Malibu

[![CI Status](http://img.shields.io/travis/hyperoslo/Malibu.svg?style=flat)](https://travis-ci.org/hyperoslo/Malibu)
[![Version](https://img.shields.io/cocoapods/v/Malibu.svg?style=flat)](http://cocoadocs.org/docsets/Malibu)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Malibu.svg?style=flat)](http://cocoadocs.org/docsets/Malibu)
[![Platform](https://img.shields.io/cocoapods/p/Malibu.svg?style=flat)](http://cocoadocs.org/docsets/Malibu)
![Swift](https://img.shields.io/badge/%20in-swift%202.2-orange.svg)

## Description

Palm trees, ocean reefs and breaking waves. Welcome to the surf club **Malibu**,
a networking library built on ***promises***. It's more than just a
wrapper around `NSURLSession`, but a powerful framework that helps to chain your
requests, validations and request processing.

Using [When](https://github.com/vadymmarkov/When) under the hood, **Malibu**
adds a lot of sugar helpers and moves your code up to the next level:

* No more "callback hell".
* Your requests are described in one place.
* Response processing could be easily broken down into multiple logical tasks.
* Data and errors are handled separately.
* Your networking code is much cleaner, readable and follows `DRY` principle.

Enjoy the ride, equipped with all necessary gears by `Malibu`, and feel yourself
like a big wave surfer in sharky waters of asynchronous networking.

## Table of Contents

* [Catching the wave](#catching-the-wave)
* [Request](#request)
  * [Content types](#content-types)
  * [Encoding](#encoding)
* [Networking](#networking)
  * [Session configuration](#session-configuration)
  * [Initialization](#initialization)
  * [Additional headers](#additional-headers)
  * [Pre-processing](#pre-processing)
  * [Making a request](#making-a-request)
  * [Wave and Ride](#wave-and-ride)
  * [Mocks](#mocks)
* [Response](#response)
  * [Serialization](#serialization)
  * [Validation](#validation)
* [Core](#core)
  * [Multiple networkings](#multiple-networkings)
  * [Backfoot surfer](#backfoot-surfer)
* [Logging](#logging)
* [Installation](#installation)
* [Author](#author)
* [Credits](#credits)
* [Contributing](#contributing)
* [License](#license)

## Catching the wave

You can start your ride straight away, not thinking about configurations:

```swift
// Declare your request
struct BoardsRequest: GETRequestable {
  var message = Message(resource: "http://sharkywaters.com/api/boards")

  init(kind: Int, text: String) {
    message.parameters = ["type": kind, "text": text]
  }
}

// Make a call
let request = BoardsRequest(kind: 1, text: "classic")

Malibu.GET(request).promise
  .validate()
  .toJSONDictionary()
  .then({ dictionary -> [Board] in
    // Let's say we use https://github.com/zenangst/Tailor for mapping
    return try dictionary.relationsOrThrow("boards") as [Board]
  })
  .done({ boards in
    // Handle response data
  })
  .fail({ error in
    // Handle errors
  })
  .always({ _ in
    // Hide progress bar
  })
```

If you still don't see any benefits, keep scrolling down and be ready for even
more magic 😉...

## Request

You can love it or you can hate it, but either way you have to create a `struct`
or a `class` representing your request. This decision has been made to separate
concerns into well-defined layers, so request with all it's properties is
described in one place, out from the actual usage.

There are 6 protocols corresponding to HTTP methods: `GETRequestable`,
`POSTRequestable`, `PATCHRequestable`, `PUTRequestable`, `DELETERequestable`,
`HEADRequestable`. Just conform to one of them and you're ready to surf.

```swift
struct BoardsRequest: GETRequestable {
  // Container for request URL, parameters and headers
  var message = Message(resource: "boards")

  // Enables or disables automatic ETags handling (enabled by default for GET).
  var etagPolicy = .Disabled

  init() {
    message.headers = ["custom": "header"]
  }
}

struct BoardCreateRequest: POSTRequestable {
  var message = Message(resource: "boards")

  // Content type is set to `.JSON` by default for POST.
  var contentType: ContentType = .FormURLEncoded

  init(kind: Int, title: String) {
    message.parameters = ["type" : kind, "title" : title]
  }
}

struct BoardDeleteRequest: DELETERequestable {
  var message = Message(resource: "boards")

  init(id: Int) {
    message = Message(resource: "boards:\(id)")
  }
}
```

### Content types

* `Query` - creates a query string to be appended to any existing URL.
* `FormURLEncoded` - uses `application/x-www-form-urlencoded` as a `Content-Type`
and formats your parameters with percent-encoding.
* `JSON` - sets the `Content-Type` to `application/json` and sends a JSON
representation of the parameters object as the body of the request.
* `MultipartFormData` - sends parameters encoded as `multipart/form-data`.
* `Custom(String)` - uses given `Content-Type` string as a header.

### Encoding

**Malibu** comes with 3 parameter encoding implementations:
* `FormURLEncoder` - a percent-escaped encoding following RFC 3986.
* `JSONEncoder` - `NSJSONSerialization` based encoding.
* `MultipartFormEncoder` - multipart data builder.

You can extend default functionality by adding a custom parameter encoder
that conforms to `ParameterEncoding` protocol:

```swift
// Override default JSON encoder.
Malibu.parameterEncoders[.JSON] = CustomJSONEncoder()

// Register encoder for the custom encoding type.
Malibu.parameterEncoders[.Custom("application/xml")] = CustomXMLEncoder()
```

## Networking

`Networking` class is a core component of **Malibu** that sets shared headers,
pre-process and executes actual HTTP requests.

### Session configuration

`Networking` is created with `SessionConfiguration` which is just a wrapper
around `NSURLSessionConfiguration` and could represent 3 standard session types
+ 1 custom type:
* `Default` - configuration that uses the global singleton credential, cache and
cookie storage objects.
* `Ephemeral` - configuration with no persistent disk storage for cookies, cache
or credentials.
* `Background` - session configuration that can be used to perform networking
operations on behalf of a suspended application, within certain constraints.  
* `Custom(NSURLSessionConfiguration)` - if you're not satisfied with standard
types, your custom `NSURLSessionConfiguration` goes here.

### Initialization

It's pretty straightforward to create a new `Networking` instance:

```swift
// Simple networking with `Default` configuration and no base URL
let simpleNetworking = Networking()

let networking = Networking(
  // Every request made on this networking will be scoped by the base URL
  baseURLString: "http://sharkywaters.com/api/",
  // `Background` session configuration
  sessionConfiguration: .Background,
  // Custom `NSURLSessionDelegate` could set if needed
  sessionDelegate: self
)
```

### Additional headers

Additional headers will be used in the each request made on the networking:

```swift
let networking = Networking(baseURLString: "http://sharkywaters.com/api/")
networking.additionalHeaders = {
  ["Accept" : "application/json"]
}
```

Note that `Accept-Language`, `Accept-Encoding` and `User-Agent` headers are
included automatically.

### Pre-processing

```swift
let networking = Networking(baseURLString: "http://sharkywaters.com/api/")

// Use this closure to modify your `Requestable` value before `NSURLRequest`
// is created on base of it.
networking.beforeEach = { request in
  var request = request
  request.message.parameters["userId"] = "12345"

  return request
}

// Use this closure to modify generated `NSMutableURLRequest` object
// before the request is made.
networking.preProcessRequest = { (request: NSMutableURLRequest) in
  request.addValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9", forHTTPHeaderField: "token")
}
```

### Making a request

`Networking` is set up and ready, so it's time to fire some requests. Make
a request by calling `GET`, `POST`, `PUT`, `PATCH`, `DELETE` or
`HEAD` functions with the corresponding request as an argument.

```swift
let networking = Networking(baseURLString: "http://sharkywaters.com/api/")

networking.GET(BoardsRequest()).promise
  .validate()
  .toJSONDictionary()
  .done({ data in
    print(data)
  })

networking.POST(BoardCreateRequest(kind: 2, title: "Balsa Fish")).promise
  .validate()
  .toJSONDictionary()
  .done({ data in
    print(data)
  })

networking.DELETE(BoardDeleteRequest(id: 11)).promise.
  fail({ error in
    print(error)
  })
```

### Wave and Ride

`Ride` object is returned by every request method. It has 2 properties:
- `NSURLSessionTask` that you might want to cancel when it's needed.
- `Promise<Wave>` that you use to add callbacks and build chains of tasks. It
has a range of useful helpers, such as validations and serialization.

`Wave` object consists of `NSData`, `NSURLRequest` and `NSHTTPURLResponse`
properties.

```swift
let ride = networking.GET(BoardsRequest())

// Cancel the task
ride.cancel()

// Create chains and add callbacks on promise object
ride.promise
  .validate()
  .toString()
  .then({ string in
    // ...
  })
  .done({ _ in
    // ...
  })
```

### Mocks

Mocking is great when it comes to writing your tests. But it also could speed
up your development process while the backend developers are working really hard
on API implementation.

In order to start mocking you have to do the following:

**Change the `mode`**

```swift
// A mode for real HTTP request only
Malibu.mode = .Regular

// A mode for mocks only
Malibu.mode = .Fake

// Both real and fake requests can be used in a mix
Malibu.mode = .Partial
```

**Register the mock**

```swift
// With response data from file
networking.register(mock: Mock(
  // Request to mock
  request: BoardsRequest(),
  // Name of the file
  fileName: "boards.json"
))

// With response from JSON dictionary
networking.register(mock: Mock(
  // Request to mock
  request: BoardsRequest(),
  // JSON dictionary
  JSON: ["boards": [["id": 1, "title": "Balsa Fish"]]]
))

// NSData mock
networking.register(mock: Mock(
  // Request to mock
  request: BoardsRequest(),
  // Needed response
  response: mockedResponse,
  // Response data
  data: responseData,
  // Custom error, `nil` by default
  error: customError
))
```

## Response

### Serialization

**Malibu** gives you a bunch of methods to serialize response data:

```swift
func toData() -> Promise<NSData>
func toString(encoding: NSStringEncoding? = nil) -> Promise<String>
func toJSONArray(options: NSJSONReadingOptions = .AllowFragments) -> Promise<[[String: AnyObject]]>
func toJSONDictionary(options: NSJSONReadingOptions = .AllowFragments) -> Promise<[String: AnyObject]>
```

### Validation

**Malibu** comes with 4 validation methods:

```swift
// Validates a status code to be within 200..<300
// Validates a response content type based on a request "Accept" header
networking.GET(BoardsRequest()).promise.validate()

// Validates a response content type
networking.GET(BoardsRequest()).promise.validate(
  contentTypes: ["application/json; charset=utf-8"]
)

// Validates a status code
networking.GET(BoardsRequest()).promise.validate(statusCodes: [200])

// Validates with custom validator conforming to `Validating` protocol
networking.GET(BoardsRequest()).promise.validate(validator: CustomValidator())
```

## Core

### Multiple networkings

**Malibu** handles multiple networkings which you can register and resolve from
the container. Doing that, it's super easy to support several APIs and
configurations in your app.

```swift
let networking = Networking(baseURLString: "http://sharkywaters.com/api/")
networking.additionalHeaders = {
  ["Accept" : "application/json"]
}

// Register
Malibu.register("base", networking: networking)

// Perform request using specified networking configuration
Malibu.networking("base").GET(BoardsRequest(kind: 1, text: "classic"))

// Unregister
Malibu.unregister("base")
```

### Backfoot surfer

**Malibu** has a shared networking object with default configurations for the
case when you need just something simple to catch the wave. It's not necessary
to invoke it directly, just call the same `GET`, `POST`, `PUT`, `PATCH`,
`DELETE` methods right on `Malibu`:

```swift
Malibu.GET(BoardsRequest())
```

## Logging

If you want to see some request, response and error info in the console, you
get this awesome feature for free. Just choose one of the available log levels:

* `None` - logging is disabled, so your console is not littered with networking
stuff.
* `Error` - prints only errors that occur during the request execution.
* `Info` - prints incoming request method + URL, response status code and errors.
* `Verbose` - prints incoming request headers and parameters in addition to
everything printed in the `Info` level.

Optionally you can set your own loggers and adjust the logging to your needs:

```swift
// Custom logger that conforms to `ErrorLogging` protocol
Malibu.logger.errorLogger = CustomErrorLogger.self

// Custom logger that conforms to `RequestLogging` protocol
Malibu.logger.requestLogger = RequestLogger.self

// Custom logger that conforms to `ResponseLogging` protocol
Malibu.logger.responseLogger = ResponseLogger.self
```

## Author

Hyper Interaktiv AS, ios@hyper.no

## Installation

**Malibu** is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Malibu'
```

**Malibu** is also available through [Carthage](https://github.com/Carthage/Carthage).
To install just write into your Cartfile:

```ruby
github "hyperoslo/Malibu"
```

## Author

Hyper Interaktiv AS, ios@hyper.no

## Contributing

We would love you to contribute to **Malibu**, check the [CONTRIBUTING](https://github.com/hyperoslo/Malibu/blob/master/CONTRIBUTING.md) file for more info.

## License

**Malibu** is available under the MIT license. See the [LICENSE](https://github.com/hyperoslo/Malibu/blob/master/LICENSE.md) file for more info.
