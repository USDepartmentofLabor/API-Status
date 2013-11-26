//
//  DOLAppDelegate.m
//  API Status
//
//  Created by Michael Pulsifer on 11/19/13.
//  Copyright (c) 2013 U.S. Department of Labor. All rights reserved.
//

#import "DOLAppDelegate.h"
#import "APIPrefsWindowController.h"

#define API_SECRET @""
//#define API_HOST @"http://api.dol.gov"
//#define API_URL @"/V1"
//#define API_KEY @"2bc4aa85-4d4e-4e33-820e-5ddbc7a1c237"

@implementation DOLAppDelegate

@synthesize dataRequest, arrayOfResults, dictionaryOfResults, preferencesMenuItem;

NSUserDefaults * prefs;


-(id)init{
    self = [super init];
    if (self) {
        prefs = [NSUserDefaults standardUserDefaults];
        NSString *registerDefaultsPlistFile = [[NSBundle mainBundle] pathForResource:@"registerDefaults" ofType:@"plist"];
        [prefs registerDefaults:[NSDictionary dictionaryWithContentsOfFile:registerDefaultsPlistFile]];
        
    }
    return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    
    // Insert code here to initialize your application
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setTitle:@""];
    [self.statusItem setHighlightMode:YES];
    [self.statusItem setImage:[NSImage imageNamed:@"graybar.png"]];
    
    //Menu items
    [self.statusMenu setAutoenablesItems:NO];
//    [self.statusMenu addItemWithTitle:@"Preferences" action:@selector(onHandlePrefs:) keyEquivalent:@""];
    NSMenuItem *tItem = nil;
    tItem = [self.statusMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [tItem setKeyEquivalentModifierMask:NSCommandKeyMask];
    
    
    
    [self submitRequest];
    
    [NSTimer scheduledTimerWithTimeInterval:900.0 target:self selector:@selector(submitRequest) userInfo:Nil repeats:YES];
}

-(void)submitRequest {
    GOVDataContext *context = [[GOVDataContext alloc] initWithAPIKey:[prefs objectForKey:@"API_KEY"] Host:[prefs objectForKey:@"API_HOST"] SharedSecret:API_SECRET APIURL:[prefs objectForKey:@"API_URL"]];
	//Instantiate a new request
	dataRequest = [[GOVDataRequest alloc] initWithContext:context];
	//Set self as a delegate
	dataRequest.delegate = self;

    
    NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys: nil];
	int timeOut = 20;
	[dataRequest callAPIMethod:[prefs objectForKey:@"API_METHOD"] withArguments:arguments andTimeOut:timeOut];
    dataRequest = nil;
    context = nil;
    
    
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithError:(NSString *)error {
        // handle error
   // NSLog(@"with error");
    [self.statusItem setImage:[NSImage imageNamed:@"graybar.png"]];
    [self.statusItem setTitle:@"API Error"];
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithResults:(NSArray *)resultsArray andResponseTime:(float)timeInMS {
    // handle results
 //   NSLog(@"%f", timeInMS);
//    float roundedTime = [[NSString stringWithFormat:@"%."]]
    [self updateMeter:timeInMS];
    resultsArray = nil;
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithUnParsedResults:(NSString *)resultsString andResponseTime:(float)timeInMS {
    // handle unparsed results
  //  NSLog(@"with unparsed results");
    [self updateMeter:timeInMS];
    resultsString = nil;
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithDictionaryResults:(NSDictionary *)resultsDictionary andResponseTime:(float)timeInMS {
    // handle dictionary results
  //  NSLog(@"with a dictionary");
    [self updateMeter:timeInMS];
    resultsDictionary = nil;
}

-(void)updateMeter:(float)timeInMS {
    NSString *apiTime = [NSString stringWithFormat:@"%.2f ms",timeInMS];
    [self.statusItem setTitle:apiTime];
    if (timeInMS < 10.0) {
        [self.statusItem setImage:[NSImage imageNamed:@"greenbar.png"]];
    }
    else if ((timeInMS >= 10.0) && (timeInMS < 100.0)) {
        [self.statusItem setImage:[NSImage imageNamed:@"yellowbar.png"]];
    } else if ((timeInMS >= 100.0) && (timeInMS < 1000.0)) {
        [self.statusItem setImage:[NSImage imageNamed:@"orangebar.png"]];
    } else {
        [self.statusItem setImage:[NSImage imageNamed:@"redbar.png"]];
    }
    
}

-(IBAction)onHandlePrefs:(id)sender {
    if (self.windowController == nil) {
        self.windowController = [[APIPrefsWindowController alloc] initWithWindowNibName:@"APIPrefsWindowController"];
    }
    [self.windowController showWindow:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_windowController];
}

-(void)windowWillClose {
 //   NSLog(@"closed!");
    NSString *registerDefaultsPlistFile = [[NSBundle mainBundle] pathForResource:@"registerDefaults" ofType:@"plist"];
    [prefs registerDefaults:[NSDictionary dictionaryWithContentsOfFile:registerDefaultsPlistFile]];
 //   NSLog(@"%@",[prefs objectForKey:@"API_URL"]);
    
}

@end
