//
//  DOLAppDelegate.m
//  API Status
//
//  Created by Michael Pulsifer on 11/19/13.
//
//  Released to the public domain

#import "DOLAppDelegate.h"
#import "APIPrefsWindowController.h"

#define API_SECRET @""

@implementation DOLAppDelegate

@synthesize dataRequest, arrayOfResults, dictionaryOfResults, preferencesMenuItem, resendMenuItem;

NSUserDefaults * prefs;


-(id)init{
    self = [super init];
    if (self) {
        // Gather the user's prefrences
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
    // Add Quit menu item
    NSMenuItem *tItem = nil;
    tItem = [self.statusMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [tItem setKeyEquivalentModifierMask:NSCommandKeyMask];
    
    
    
    // Start off with a measurement
    [self submitRequest];
    
    // Set up timer to send a request to the API every 15 minutes
    [NSTimer scheduledTimerWithTimeInterval:900.0 target:self selector:@selector(submitRequest) userInfo:Nil repeats:YES];
}

-(void)submitRequest {
    
    // Create context and request objects
    GOVDataContext *context = [[GOVDataContext alloc] initWithAPIKey:[prefs objectForKey:@"API_KEY"] Host:[prefs objectForKey:@"API_HOST"] SharedSecret:API_SECRET APIURL:[prefs objectForKey:@"API_URL"]];
	//Instantiate a new request
	dataRequest = [[GOVDataRequest alloc] initWithContext:context];
	//Set self as a delegate
	dataRequest.delegate = self;

    // Set API arguments dictionary to be empty.  Used by the SDK
    NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys: nil];

	// Set timeOut.  Used by the SDK (deprecated).
    int timeOut = 20;
    
    // Submit the request
	[dataRequest callAPIMethod:[prefs objectForKey:@"API_METHOD"] withArguments:arguments andTimeOut:timeOut];

    // Cleanup
    dataRequest = nil;
    context = nil;
    
    
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithError:(NSString *)error {
        // handle error
    [self.statusItem setImage:[NSImage imageNamed:@"graybar.png"]];
    [self.statusItem setTitle:@"API Error"];
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"API Error";
    notification.informativeText = error;
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithResults:(NSArray *)resultsArray andResponseTime:(float)timeInMS {
    // handle results
    [self updateMeter:timeInMS];
    resultsArray = nil;
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithUnParsedResults:(NSString *)resultsString andResponseTime:(float)timeInMS {
    // handle unparsed results
    [self updateMeter:timeInMS];
    resultsString = nil;
}

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithDictionaryResults:(NSDictionary *)resultsDictionary andResponseTime:(float)timeInMS {
    // handle dictionary results
    [self updateMeter:timeInMS];
    resultsDictionary = nil;
}

-(void)updateMeter:(float)timeInMS {

    // Update status in the menubar.  Scale is logarithmic.
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

    // handle user selection of the Preferences menu item.
    if (self.windowController == nil) {
        self.windowController = [[APIPrefsWindowController alloc] initWithWindowNibName:@"APIPrefsWindowController"];
    }
    [self.windowController showWindow:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:_windowController];
}

-(IBAction)onHandleResend:(id)sender {
    // handle user selection of the Send API Request - used when the user doesn't want to wait 15 minutes
    [self submitRequest];
}

-(void)windowWillClose {
    // Do cleanup of the preferences data in memory when the preferences window is closed.
    NSString *registerDefaultsPlistFile = [[NSBundle mainBundle] pathForResource:@"registerDefaults" ofType:@"plist"];
    [prefs registerDefaults:[NSDictionary dictionaryWithContentsOfFile:registerDefaultsPlistFile]];
    
}

@end
