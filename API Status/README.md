## Description

MCCURLConnection is a Very Lightweight Queued NSURLConnection

Features:

* Only _ONE_ class to import! 600 lines long.
* Asynchronous downloads
* Use blocks as delegate methods
* Callbacks are run out of the main thread
* Control concurrency with Operation queues
* Cancel connections
* Manage application wide or context wide behaviors.
* and many more...


## Basic usage

### With "global" queue context 

Class methods are used to provide a default "global" context.

```objective-c
[[MCCURLConnection connectionWithRequest:request onFinished:^(MCCURLConnection *connection) { ... }];
```


### With a custom queue context

Instance methods are used to provide a custom context. 

```objective-c
 MCCURLConnection *context = [MCCURLConnection context];
 context.queue = myQueue; // myQueue is a NSOperationQueue object
```

Then, submit multiple connections to this queue context:

```objective-c
[context connectionWithRequest:request1 onFinished:^(MCCURLConnection *connection) { ... }];
...
[context connectionWithRequest:request2 onFinished:^(MCCURLConnection *connection) { ... }];
```

### Connections

There are two ways to create a connection. They both deliver an autoreleased connection object.

#### using "connection"

```objective-c
MCCURLConnection *connection1 = [MCCURLConnection connection]; 

...

// When you are ready to start the connection, you must enqueue it's request:
[connection1 enqueueRequest:MyRequest1];
```

#### using "connectionWithRequest:onFinished:"

```objective-c
MCCURLConnection *connection2 = [MCCURLConnection connectionWithRequest:MyRequest2 onFinished:^(MCCURLConnection *connection) { ... }];
```

This method enqueues the request automatically. 


####  callbacks
You may register these callbacks on the connection object (see MCCURLConnection.h):

* onResponse
* onData
* onFinished
* onWillCacheResponse

example:
```objective-c
MCCURLConnection *connection2 = [MCCURLConnection connectionWithRequest:MyRequest2 onFinished:^(MCCURLConnection *connection) { ... }];
connection2.onData = ^(NSData *chunk) {
  ...
};
```

#### States

Each connection has a defined state which can be accessed from the _state_ ivar.
Moreover, when a connection is finished, you can access the _finishedState_ ivar which tells you how it finished, whether it has been cancelled, or encountered an error etc... (see MCCURLConnection.h)

Also, each connection maintains these accessors: 

* httpStatusCode (filled in response to a HTTP request)
* error (filled when an error occured, like no network, timeouts etc...)
* data (only filled when no onData callback is registered)
* response (filled when a response is received from the server)

#### Other

You may attach any objective-c object to the connection using the _userInfo_ ivar. It will be retained and released when the connection is deallocated.

### Context

Each context whether global (Class) or custom (instance) conforms to the MCCURLConnectionContextProtocol (see MCCURLConnection.h) in which you can configure:

* the operation queue
* the unique request policy enforcement
* the onRequest callback
* the authentication delegate


#### onRequest

This callback is run when a connection has just started or finished (state == ConnectionStateStarted || state == ConnectionStateFinished)
Note that when this callback is set on the global context (Class) it will always be triggered, even from connections bound to a custom context. 

It can be useful to set this callback in the global context to manage the network activity indicator view application-wide:

```objective-c
[MCCURLConnection setOnRequest:^(MCCURLConnection *connection) { 
  static int live = 0;
  
  if (connection.state == ConnectionStateFinished) live--;
  else live++;
  
  [application setNetworkActivityIndicatorVisible:!!live];
}];
```


#### Unique requests policy enforcement

By default, each HTTP request must be unique. This policy can be changed by setting the _enforcesUniqueRequestedResource_ ivar to FALSE in which case many duplicate requests can be run. 

When the policy is enforced, to determine if a request is a duplicate, we concatenate the requested method and the requested URL. This identifier which should be unique is stored in the _identifier_ ivar.

However, if you set the identifier ivar of the connection, prior to the start of the operation (in the operation queue) you can control the uniqueness checking.


## Test
I have included a sort of test (main.m) and a sort of nodejs server. 
To run the tests, you need to run the server:

```
$ node server.js
```

And then compile and run the main.m

## License terms

Copyright (c), 2012 Thierry Passeron

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
