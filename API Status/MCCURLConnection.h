//
//  MCCURLConnection.h
//
//  Created by Thierry Passeron on 02/09/12.
//  Copyright (c) 2012 Monte-Carlo Computing. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
  ConnectionStateNone = 0,
  ConnectionStateEnqueued = 1,
  ConnectionStateStarted = 10,
  ConnectionStateFinished = 20
} MCCURLConnectionState;

typedef enum {
  FinishedStateNone = 0,
  FinishedStateInvalid,
  FinishedStateCancelled,
  FinishedStateError,
  FinishedStateOK = 10
} MCCURLConnectionFinishedState;

@class MCCURLConnection;
@protocol MCCURLConnectionContextProtocol <NSObject>
@property (retain, nonatomic) NSOperationQueue *queue;
@property (assign, nonatomic) BOOL enforcesUniqueRequestedResource;
@property (copy, nonatomic) void(^onRequest)(MCCURLConnection *);
@property (assign, nonatomic) id authenticationDelegate;
- (id)connection;
- (void)enqueueRequest:(NSURLRequest *)request;
- (id)connectionWithRequest:(NSURLRequest *)request onFinished:(void(^)(MCCURLConnection *))onFinishedCallback;
@end

@interface MCCURLConnection : NSObject

@property (copy, nonatomic) void(^onResponse)(NSURLResponse *response);
@property (copy, nonatomic) void(^onData)(NSData *chunk);
@property (copy, nonatomic) void(^onFinished)(MCCURLConnection *connection);
@property (copy, nonatomic) NSCachedURLResponse *(^onWillCacheResponse)(NSCachedURLResponse *);

@property (retain, nonatomic) id userInfo; // You may set any objective-c object as userInfo
@property (retain, nonatomic) NSString *identifier; // Use this to provide a custom identifier for unique request enforcement. The default identifier is @"<HTTP_METHOD> <URL>"

- (NSURLResponse *)response;  // Automatically set when a response is received
- (NSMutableData *)data;      // Automatically filled _ONLY_ when NO onData callback is specified
- (NSError *)error;           // Automatically set when the connection is finished with an error
- (NSInteger)httpStatusCode;  // Automatically set when a HTTP response is received

- (MCCURLConnectionState)state;
- (MCCURLConnectionFinishedState)finishedState;

/* cancel the connection */
- (void)cancel;



#pragma mark Global context

/* globaly set whether ongoing requested resources must be unique, default is TRUE */
+ (void)setEnforcesUniqueRequestedResource:(BOOL)unique;

/* set a default onRequest callback */
+ (void)setOnRequest:(void(^)(MCCURLConnection *))callback;

/* set a default queue */
+ (void)setQueue:(NSOperationQueue *)queue;

/* set a global authentication delegate that will be used for all authentications */
+ (void)setAuthenticationDelegate:(id)aDelegate;



/* Return an autoreleased connection bound to the global context */
+ (id)connection;

// Convenient shortcut method
/* Return an enqueued connection in the global context */
+ (id)connectionWithRequest:(NSURLRequest *)request onFinished:(void(^)(MCCURLConnection *connection))onFinishedCallback;



#pragma mark Custom context

/* Return an autoreleased custom context */
+ (id)context;

@property (retain, nonatomic) NSOperationQueue *queue;
@property (assign, nonatomic) BOOL enforcesUniqueRequestedResource;
@property (copy, nonatomic) void(^onRequest)(MCCURLConnection *);
@property (assign, nonatomic) id authenticationDelegate;


/* Return an autoreleased connection bound to the custom context.  */
- (id)connection;

/* enqueue the connection operation in it's target queue to start the given request */
- (void)enqueueRequest:(NSURLRequest *)request;

/* Return an enqueued connection for the context */
- (id)connectionWithRequest:(NSURLRequest *)request onFinished:(void(^)(MCCURLConnection *))onFinishedCallback;

@end
