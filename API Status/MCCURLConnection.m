//
//  MCCURLConnection.m
//
//  Created by Thierry Passeron on 02/09/12.
//  Copyright (c) 2012 Monte-Carlo Computing. All rights reserved.
//

#import "MCCURLConnection.h"

//#define DEBUG_MCCURLConnection

#pragma mark debugging material
#ifdef DEBUG_MCCURLConnection
@interface NSURLCache (MCCURLConnectionAddons)
@end
@implementation NSURLCache (MCCURLConnectionAddons)
- (NSString *)description {
  return [NSString stringWithFormat:@"%@:\n\tDisk (u/c): %.3f MB / %.3f MB\n\tMemory (u/c): %.3f MB / %.3f MB", NSStringFromClass([self class]),
          (float)self.currentDiskUsage / 1000000.0f, (float)self.diskCapacity / 1000000.0f, (float)self.currentMemoryUsage / 1000000.0f, (float)self.memoryCapacity / 1000000.0f];
}
@end

@interface WatchDog : NSObject
@property (retain, nonatomic) NSTimer *timer;
@property (retain, nonatomic) NSMutableArray *objects;
@property (assign, nonatomic) NSInteger totalWatch;
@property (assign, nonatomic) NSInteger totalUnwatch;
+ (id)watchDogWithTimeInterval:(NSTimeInterval)interval;
- (void)watchObject:(id)obj usingBlock:(void(^)(id))block;
- (void)unwatchObject:(id)obj;
@end

@implementation WatchDog

static dispatch_queue_t __sync = nil;
+ (void)initialize {
  __sync = dispatch_queue_create("com.mcc.watchdog", 0);
}

+ (id)watchDogWithTimeInterval:(NSTimeInterval)interval {
  WatchDog *dog = [[[self alloc]init]autorelease];
  if (!dog) return nil;
  dog.timer = [NSTimer scheduledTimerWithTimeInterval:interval target:dog selector:@selector(watch:) userInfo:nil repeats:YES];
  return dog;
}

- (id)init {
  self = [super init];
  if (!self) return nil;
  
  self.objects = [NSMutableArray array];
  self.totalWatch = 0;
  self.totalUnwatch = 0;
  
  return self;
}

- (void)dealloc {
  [self.timer invalidate];
  self.timer = nil;
  self.objects = nil;
  [super dealloc];
}

- (void)watch:(id)sender {
  dispatch_async(__sync, ^{
    NSLog(@"* WatchDog %p\n\tTotals (w/u): %d/%d\n\tWatching: %d\n", self, self.totalWatch, self.totalUnwatch, self.objects.count);
    [self.objects enumerateObjectsUsingBlock:^(id objAndBlock, NSUInteger idx, BOOL *stop) {
      id obj = [[((NSValue*)objAndBlock[0])nonretainedObjectValue]retain];
      void(^block)(id) = objAndBlock[1];
      block(obj);
      [obj release];
    }];
  });
}

- (void)unwatchObject:(id)anObj {
  NSLog(@"* WatchDog %p stop watching %p", self, anObj);
  __block id tobeRemoved = nil;
  dispatch_sync(__sync, ^{
    self.totalUnwatch++;
    [self.objects enumerateObjectsUsingBlock:^(id objAndBlock, NSUInteger idx, BOOL *stop) {
      if (anObj == [((NSValue*)objAndBlock[0])nonretainedObjectValue]) {
        tobeRemoved = objAndBlock;
        *stop = TRUE;
      }
    }];
    if (tobeRemoved) [self.objects removeObject:tobeRemoved];
  });
}

- (void)watchObject:(id)obj usingBlock:(void (^)(id))block {
  NSLog(@"* WatchDog %p start watching %p", self, obj);
  dispatch_sync(__sync, ^{
    self.totalWatch++;
    [self.objects addObject:@[[NSValue valueWithNonretainedObject:obj], block]];
  });
}

@end
#endif






@interface MCCURLConnection () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (retain, nonatomic) NSURLConnection *uconnection;

@property (assign, atomic) BOOL shouldCancel;
@property (assign, nonatomic) BOOL isContext;

@property (retain, nonatomic) NSURLResponse *response;
@property (retain, nonatomic) NSMutableData *data;
@property (retain, nonatomic) NSError *error;
@property (assign, nonatomic) NSInteger httpStatusCode;

@property (assign, nonatomic) MCCURLConnectionState state;
@property (assign, nonatomic) MCCURLConnectionFinishedState finishedState;

@property (assign, nonatomic) id<MCCURLConnectionContextProtocol> context; // Weak reference to the context. You must retain the context.
@property (retain, nonatomic) NSMutableArray *connections;

@end



@implementation MCCURLConnection

@synthesize queue = _queue;
@synthesize enforcesUniqueRequestedResource = _enforcesUniqueRequestedResource;
@synthesize onRequest = _onRequest;
@synthesize authenticationDelegate = _authenticationDelegate;
@synthesize state = _state;
@synthesize finishedState = _finishedState;
@synthesize connections= _connections;


#pragma mark init/dealloc

static dispatch_queue_t __synchronized = nil; /* Queue used for inter-thread sync like when cancelling a connection */
static NSMutableDictionary *__ongoings = nil;

static long long __initedCount = 0;
#ifdef DEBUG_MCCURLConnection
static WatchDog *__watchdog = nil;
#endif

+ (void)initialize {
  __synchronized = dispatch_queue_create("com.mcc.connections", NULL);
  
  __queue = [[NSOperationQueue alloc]init];
  __queue.maxConcurrentOperationCount = 1;
  
  __ongoings = [[NSMutableDictionary alloc]init];
  __connections = [[NSMutableArray alloc]init];
  
  #ifdef DEBUG_MCCURLConnection
  __watchdog = [[WatchDog watchDogWithTimeInterval:10 /* seconds */]retain];
  #endif
}

- (id)init {
  self = [super init];
  if (!self) return nil;
  
  _state = ConnectionStateNone;
  _finishedState = FinishedStateNone;
  _shouldCancel = FALSE;
  
  _isContext = FALSE;
  _context = (id<MCCURLConnectionContextProtocol>)self.class;
  
  __initedCount++;
  
  #ifdef DEBUG_MCCURLConnection
  NSLog(@"init: %p (living: %lld)", self, __initedCount);
  #endif
  
  return self;
}

- (void)dealloc {
  __initedCount--;
  
  #ifdef DEBUG_MCCURLConnection
  [__watchdog unwatchObject:self];
  NSLog(@"dealloc: %p (left: %lld)", self, __initedCount);
  #endif
  
  if (_isContext) {
    #ifdef DEBUG_MCCURLConnection
    if (self.connections.count) NSLog(@"Cleaning context connections: %d", self.connections.count);
    #endif
    for (MCCURLConnection *c in self.connections) {
    #ifdef DEBUG_MCCURLConnection
      NSLog(@"Cancelling connection: %p", c);
    #endif
      [c cancel];
    }
    self.connections = nil;
  }
  
  self.response = nil;
  self.data = nil;
  self.error = nil;
  self.userInfo = nil;
  self.identifier = nil;
  [_queue release];
  [_onRequest release];
  self.uconnection = nil;
  self.onResponse = nil;
  self.onData = nil;
  self.onFinished = nil;
  self.onWillCacheResponse = nil;
  
  [super dealloc];
}



#pragma mark Global settings

static BOOL __enforcesUniqueRequestedResource = TRUE;
+ (void)setEnforcesUniqueRequestedResource:(BOOL)enforce { __enforcesUniqueRequestedResource = enforce; }
+ (BOOL)enforcesUniqueRequestedResource { return __enforcesUniqueRequestedResource; }

static void(^__onRequest)(MCCURLConnection *) = nil;
+ (void)setOnRequest:(void(^)(MCCURLConnection *))callback { if (__onRequest) { Block_release(__onRequest); } __onRequest = [callback copy]; }
+ (void(^)(MCCURLConnection *))onRequest { return __onRequest; }

static NSOperationQueue *__queue = nil;
+ (void)setQueue:(NSOperationQueue *)queue { if (__queue) { [__queue autorelease]; } __queue = [queue retain]; }
+ (NSOperationQueue *)queue { return __queue; }

static id <NSURLConnectionDelegate> __authenticationDelegate = nil;
+ (void)setAuthenticationDelegate:(id<NSURLConnectionDelegate>)authDelegate { __authenticationDelegate = authDelegate; }
+ (id<NSURLConnectionDelegate>)authenticationDelegate { return __authenticationDelegate; }

static NSMutableArray *__connections = nil;
+ (NSMutableArray*)connections { return __connections; }


+ (NSString *)log {
  NSMutableString *l = [NSMutableString stringWithFormat:@"%@: Living: (%lld), Enforced ongoings (%ld):\n", NSStringFromClass(self), __initedCount, (unsigned long)__ongoings.allKeys.count];
  [__ongoings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) { [l appendFormat:@"\t%p (%@)\n", obj, key]; }];
  [l appendFormat:@"\nLive connections: %d\n", self.connections.count];
  for (MCCURLConnection *c in self.connections) {
    [l appendFormat:@"\t%p: %@ (state: %@, finishedState: %@)\n", c, c.identifier, NSStringFromState(c.state), NSStringFromFinishedState(c.finishedState)];
  }
  return l;
}



#pragma mark private methods

#define ConnectionStateValidation 5
#define ConnectionStateWillStart 7

- (void)setState:(MCCURLConnectionState)state {
  if (   ((_state == ConnectionStateNone)       && !(state == ConnectionStateEnqueued))
      || ((_state == ConnectionStateEnqueued)   && !((state == ConnectionStateValidation) || (state == ConnectionStateFinished)))
      || ((_state == ConnectionStateValidation) && !((state == ConnectionStateWillStart) || (state == ConnectionStateFinished)))
      || ((_state == ConnectionStateWillStart)  && !((state == ConnectionStateStarted) || (state == ConnectionStateFinished)))
      || ((_state == ConnectionStateStarted)    && !(state == ConnectionStateFinished))
      ) {
    NSCAssert(FALSE, @"Invalid state transition %d -> %d", _state, state);
  }
  
  _state = state;
  
  void(^onRequest)(MCCURLConnection *) = [self onRequest];
  
  switch ((int)state) {
    case ConnectionStateEnqueued:
      
      #ifdef DEBUG_MCCURLConnection
      NSLog(@"^ Enqueued %p", self);
      #endif

      break;
    case ConnectionStateValidation:
      
      #ifdef DEBUG_MCCURLConnection
      NSLog(@"^ Validation %p", self);
      #endif
      
      break;
    case ConnectionStateWillStart:;
      
      #ifdef DEBUG_MCCURLConnection
      NSLog(@"^ Will start %p", self);
      #endif
            
      break;
    case ConnectionStateStarted:;

      #ifdef DEBUG_MCCURLConnection
      NSLog(@"^ Started %p", self);
      #endif
      
      if (__onRequest && (__onRequest != onRequest)) { __onRequest(self); }
      if (onRequest) { onRequest(self); }

      break;
    case ConnectionStateFinished:
      
      #ifdef DEBUG_MCCURLConnection
      NSLog(@"^ Finished %p", self);
      #endif
      
      [self.uconnection cancel]; // Safety, not necessary.
      self.uconnection = nil;
      [self removeFromOngoings];
      if (_onFinished) _onFinished(self);
      if (onRequest) { onRequest(self); }
      if (__onRequest && (__onRequest != onRequest)) { __onRequest(self); }
      
      break;
      
    default:
      break;
  }
}

- (BOOL)shouldEnforceUniqueRequestedResource {
  if (_isContext) return _enforcesUniqueRequestedResource;
  return [_context enforcesUniqueRequestedResource];
}

- (void (^)(MCCURLConnection *))onRequest {
  if (_isContext) { return _onRequest; }
  return [_context onRequest];
}

- (NSOperationQueue *)queue {
  if (_isContext) return _queue;
  return [_context queue];
}

- (id)authenticationDelegate {
  if (_isContext) return _authenticationDelegate;
  return [_context authenticationDelegate];
}

- (NSMutableArray *)connections {
  if (_isContext) return _connections;
  return [(MCCURLConnection *)_context connections];
}

- (BOOL)validateRequest:(NSURLRequest *)request {
  if (![self shouldEnforceUniqueRequestedResource]) return YES;
  
  if (!self.identifier) {
    // Build the unique identifier of the request
    NSString *HTTPMethod = [[request HTTPMethod]uppercaseString];
    if (!HTTPMethod) {
      self.identifier = [NSString stringWithFormat:@"%@", [request URL]];
    } else {
      self.identifier = [NSString stringWithFormat:@"%@ %@", HTTPMethod, [request URL]];
    }
  }
  
  if ([__ongoings valueForKey:self.identifier]) {
    NSLog(@"Duplicate request %p (%@)", self, self.identifier);
    NSLog(@"%@", [[self class]log]);
    return FALSE;
  }
  
  [__ongoings setValue:self forKey:self.identifier];
  
  return TRUE;
}

- (void)removeFromOngoings {
  if (self.identifier) [__ongoings removeObjectForKey:self.identifier];
}



#pragma mark connection and context management

+ (id)connection { return [[[[self class]alloc]init]autorelease]; }

+ (id)connectionWithRequest:(NSURLRequest *)request onFinished:(void(^)(MCCURLConnection *))onFinishedCallback {
  MCCURLConnection *connection = [self connection];
  connection.onFinished = onFinishedCallback;
  [connection enqueueRequest:request];
  return connection;
}

- (void)cancel {
  #ifdef DEBUG_MCCURLConnection
  NSLog(@"Should cancel: %p", self);
  #endif
  
  self.shouldCancel = TRUE;
  self.finishedState = FinishedStateCancelled;

  // Shortcut for immediate cancel
  if (self.uconnection) {
    [self.uconnection cancel];
    self.uconnection = nil;
  }
  
  dispatch_async(__synchronized, ^{
    if (self.state != ConnectionStateFinished) {
      [self.uconnection cancel];
      self.uconnection = nil;

      #ifdef DEBUG_MCCURLConnection
      NSLog(@"Cancelled: %p", self);
      #endif
      
      self.state = ConnectionStateFinished;
    }
  });
}



#pragma mark context

+ (id)context {
  MCCURLConnection *context = [[[self alloc]init]autorelease];
  context.isContext = TRUE;
  context.context = nil;
  context.queue = __queue;
  context.connections = [NSMutableArray array];
  return context;
}

- (void)setQueue:(NSOperationQueue *)queue {
  NSAssert(_isContext, @"Only context can set queue");
  NSAssert(queue != [NSOperationQueue mainQueue], @"Main thread is not allowed for connections");
  if (_queue) { [_queue autorelease]; }
  _queue = [queue retain];
}

- (void)setEnforcesUniqueRequestedResource:(BOOL)enforcesUniqueRequestedResource {
  NSAssert(_isContext, @"Only context can set enforces unique requested resources");
  _enforcesUniqueRequestedResource = enforcesUniqueRequestedResource;
}

- (void)setOnRequest:(void (^)(MCCURLConnection *))onRequest {
  NSAssert(_isContext, @"Only context can set onRequest");
  if (_onRequest) { Block_release(_onRequest); }
  _onRequest = [onRequest copy];
}

- (void)setAuthenticationDelegate:(id)authenticationDelegate {
  NSAssert(_isContext, @"Only context can set authentication delegate");
  _authenticationDelegate = authenticationDelegate;
}



#pragma mark connection

- (id)connection {
  NSAssert(_isContext, @"Only context can create a connection");
  
  MCCURLConnection *connection = [[[[self class]alloc]init]autorelease];
  connection.context = (MCCURLConnection<MCCURLConnectionContextProtocol>*)self; // Weak reference. You must retain the context
  
  return connection;
}

- (id)connectionWithRequest:(NSURLRequest *)request onFinished:(void(^)(MCCURLConnection *))onFinishedCallback {
  MCCURLConnection *connection = [self connection];
  connection.onFinished = onFinishedCallback;
  [connection enqueueRequest:request];
  return connection;
}

- (void)enqueueRequest:(NSURLRequest *)request {
  NSAssert(!_isContext, @"Cannot enqueue a context");

  NSOperationQueue *queue = [self queue];
  NSAssert(queue, @"No queue!");
  
  // We keep a reference to this connection so that we can cancel all of them when the context is released
  [self.connections addObject:self];
  
  dispatch_async(__synchronized, ^{
    self.state = ConnectionStateEnqueued;
  });
    
  [queue addOperationWithBlock:^{
    #ifdef DEBUG_MCCURLConnection
    NSLog(@"Operation start: %p", self);
    #endif
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    
    
    // Critical section begin
    __block BOOL shouldReturn = FALSE;
    
    dispatch_sync(__synchronized, ^{
      
      // Early cancels
      if (self.shouldCancel) {
        shouldReturn = TRUE;
        return;
      }
      
      self.state = ConnectionStateValidation;
      
      if (![self validateRequest:request]) {
        self.finishedState = FinishedStateInvalid;
        self.state = ConnectionStateFinished;
        shouldReturn = TRUE;
        return;
      }
      
      self.state = ConnectionStateWillStart;
      
      // Start the real connection
      self.uconnection = [[[NSURLConnection alloc]initWithRequest:request delegate:self startImmediately:NO]autorelease];
      [self.uconnection scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
      [self.uconnection start];
      
      self.state = ConnectionStateStarted;
    });
    
    if (shouldReturn) goto FINISHED;
    
    do {
      #ifdef DEBUG_MCCURLConnection
      NSLog(@"%p ... ", self);
      #endif
      if (self.shouldCancel) break;
      [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
      
    } while (!self.shouldCancel && (self.state == ConnectionStateStarted));
    
    
  FINISHED:
    [self.connections removeObject:self];
    
    #ifdef DEBUG_MCCURLConnection
    [__watchdog watchObject:self usingBlock:^(id obj) {
      NSLog(@"Living connection object: %@", [obj description]);
    }];
    NSLog(@"Operation end: %p", self);
    #endif
  }];
}



#pragma mark accessors and stuff

- (NSData *)data { return _data; }
- (NSURLResponse *)response { return _response; }
- (NSError *)error { return _error; }
- (NSInteger)httpStatusCode { return _httpStatusCode; }

- (MCCURLConnectionState)state { return _state; }
- (MCCURLConnectionFinishedState)finishedState { return _finishedState; }

NS_INLINE NSString *NSStringFromState(MCCURLConnectionState state) {
  switch ((int)state) {
    case ConnectionStateNone:
      return @"None";
      break;
    case ConnectionStateEnqueued:
      return @"Enqueued";
      break;
    case ConnectionStateFinished:
      return @"Finished";
      break;
    case ConnectionStateStarted:
      return @"Started";
      break;
    case ConnectionStateValidation:
      return @"*Validation*";
      break;
    case ConnectionStateWillStart:
      return @"*Will start*";
      break;
  }
  return nil;
}

NS_INLINE NSString *NSStringFromFinishedState(MCCURLConnectionFinishedState state) {
  switch ((int)state) {
    case FinishedStateNone:
      return @"None";
      break;
    case FinishedStateCancelled:
      return @"Cancelled";
      break;
    case FinishedStateInvalid:
      return @"Invalid";
      break;
    case FinishedStateError:
      return @"Error";
      break;
    case FinishedStateOK:
      return @"OK";
      break;
  }
  return nil;
}

- (NSString *)description {
  if (_isContext) {
    NSMutableString *desc = [NSMutableString stringWithFormat:@"%@ (%p) queue context: %@ (onRequest:%@), enforcement: %@", [self class], self, _queue == __queue ? @"Default Queue" : _queue, _onRequest, [self enforcesUniqueRequestedResource] ? @"Yes": @"No"];
    if (self.connections.count) {
      [desc appendFormat:@"\nLive connections: %d\n", self.connections.count];
      for (MCCURLConnection *c in self.connections) {
        [desc appendFormat:@"\t%p: %@ (state: %@, finishedState: %@)\n", c, c.identifier, NSStringFromState(c.state), NSStringFromFinishedState(c.finishedState)];
      }
    }
    return desc;
  }
  
  NSMutableString *desc = [NSMutableString stringWithFormat:@"%@ (%p) connection\n", [self class], self];
                   [desc appendFormat:@"\tState:            %@\n", NSStringFromState(self.state)];
                   [desc appendFormat:@"\tQueue:            %@\n", self.queue == __queue ? @"Default Queue" : _context.queue];
  if (_uconnection)[desc appendFormat:@"\tConnection:       %@\n", _uconnection];
  if (self.state == ConnectionStateFinished)
                   [desc appendFormat:@"\tFinished state:   %@\n", NSStringFromFinishedState(self.finishedState)];
                   [desc appendFormat:@"\tHTTP status code: %ld\n", (long)_httpStatusCode];
  if (_error)      [desc appendFormat:@"\tError:            %@\n", _error];
  if (_identifier) [desc appendFormat:@"\tIdentifier:       %@\n", _identifier];
  
  if (_onResponse) [desc appendFormat:@"\tonResponse:       %@\n", _onResponse];
  if (_onData)     [desc appendFormat:@"\tonData:           %@\n", _onData];
  if (_onFinished) [desc appendFormat:@"\tonFinished:       %@\n", _onFinished];
  if (self.data.length)
                   [desc appendFormat:@"\tData:             %ld bytes\n", (unsigned long)self.data.length];
                   [desc appendFormat:@"\tContext:          %@\n", self.context];
  
  return desc;
}



#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  if (_state != ConnectionStateStarted) return;
  
  #ifdef DEBUG_MCCURLConnection
  NSLog(@"*** response in %p", self);
  #endif
  
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    _httpStatusCode = [(NSHTTPURLResponse*)response statusCode];
  }

  self.response = response;
  self.data = [NSMutableData data];

  if (_onResponse) _onResponse(response);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)chunk {
  if (_state != ConnectionStateStarted) return;

  #ifdef DEBUG_MCCURLConnection
  NSLog(@"*** chunk in %p", self);
  #endif
  
  if (_onData) _onData(chunk);
  else [self.data appendData:chunk];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
  if (_state != ConnectionStateStarted) return;

  #ifdef DEBUG_MCCURLConnection
  NSLog(@"*** did finish in %p", self);
  #endif
  
  self.finishedState = FinishedStateOK;
  dispatch_async(__synchronized, ^{
    self.state = ConnectionStateFinished;
  });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError {
  if (_state != ConnectionStateStarted) return;

  #ifdef DEBUG_MCCURLConnection
  NSLog(@"*** did fail in %p", self);
  #endif

  self.error = anError;
  self.finishedState = FinishedStateError;
  
  dispatch_async(__synchronized, ^{
    self.state = ConnectionStateFinished;
  });
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
  if (_state != ConnectionStateStarted) return nil;
  #ifdef DEBUG_MCCURLConnection
  NSLog(@"** will cache response in %p (cache: %@)", self, [NSURLCache sharedURLCache]);
  #endif
  return _onWillCacheResponse ? _onWillCacheResponse(cachedResponse) : cachedResponse;
}



#pragma mark Authentication delegate methods

- (BOOL)connection:(NSURLConnection *)aConnection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
  id delegate = [self authenticationDelegate];
  return delegate && [delegate respondsToSelector:@selector(connection:canAuthenticateAgainstProtectionSpace:)] ? [delegate connection:aConnection canAuthenticateAgainstProtectionSpace:protectionSpace] : NO;
}

- (void)connection:(NSURLConnection *)aConnection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  id delegate = [self authenticationDelegate];
  if (delegate  && [delegate respondsToSelector:@selector(connection:didCancelAuthenticationChallenge:)])
    [delegate connection:aConnection didCancelAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  id delegate = [self authenticationDelegate];
  if (delegate  && [delegate respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:)])
    [delegate connection:aConnection didReceiveAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)aConnection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  id delegate = [self authenticationDelegate];
  if (delegate  && [delegate respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)])
    [delegate connection:aConnection willSendRequestForAuthenticationChallenge:challenge];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)aConnection {
  id delegate = [self authenticationDelegate];
  return delegate && [delegate respondsToSelector:@selector(connectionShouldUseCredentialStorage:)] ? [delegate connectionShouldUseCredentialStorage:aConnection] : YES;
}

@end
