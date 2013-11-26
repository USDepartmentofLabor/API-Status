//
//  APIPrefsWindowController.m
//  API Status
//
//  Created by Michael Pulsifer on 11/22/13.
//
//  Released to the public domain

#import "APIPrefsWindowController.h"
#import "DOLAppDelegate.h"

@interface APIPrefsWindowController ()

@end

@implementation APIPrefsWindowController


@synthesize keyTextField, hostTextField, urlTextField, methodTextField;

NSUserDefaults * prefs;


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        prefs = [NSUserDefaults standardUserDefaults];
        NSString *registerDefaultsPlistFile = [[NSBundle mainBundle] pathForResource:@"registerDefaults" ofType:@"plist"];
        [prefs registerDefaults:[NSDictionary dictionaryWithContentsOfFile:registerDefaultsPlistFile]];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setDelegate:self];

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.keyTextField setStringValue:[prefs objectForKey:@"API_KEY"]];
    [self.hostTextField setStringValue:[prefs objectForKey:@"API_HOST"]];
    [self.urlTextField setStringValue:[prefs objectForKey:@"API_URL"]];
    [self.methodTextField setStringValue:[prefs objectForKey:@"API_METHOD"]];
}

-(BOOL)windowShouldClose:(id)sender {
    // Save the user's preferences when they close the window
    [[NSUserDefaults standardUserDefaults] setObject:[self.keyTextField stringValue] forKey:@"API_KEY"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.hostTextField stringValue] forKey:@"API_HOST"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.urlTextField stringValue] forKey:@"API_URL"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.methodTextField stringValue] forKey:@"API_METHOD"];

    // Let the delegate know what's happening
    [(DOLAppDelegate *)[[NSApplication sharedApplication] delegate] windowWillClose];
    
    return YES;
}

@end
