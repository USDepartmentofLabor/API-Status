//
//  APIPrefsWindowController.m
//  API Status
//
//  Created by Michael Pulsifer on 11/22/13.
//  Copyright (c) 2013 U.S. Department of Labor. All rights reserved.
//

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
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self];
    //NSLog(@"pref window!");
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.keyTextField setStringValue:[prefs objectForKey:@"API_KEY"]];
    [self.hostTextField setStringValue:[prefs objectForKey:@"API_HOST"]];
    [self.urlTextField setStringValue:[prefs objectForKey:@"API_URL"]];
    [self.methodTextField setStringValue:[prefs objectForKey:@"API_METHOD"]];
}

-(BOOL)windowShouldClose:(id)sender {
   // NSLog(@"about to close the window!");
    [[NSUserDefaults standardUserDefaults] setObject:[self.keyTextField stringValue] forKey:@"API_KEY"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.hostTextField stringValue] forKey:@"API_HOST"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.urlTextField stringValue] forKey:@"API_URL"];
    [[NSUserDefaults standardUserDefaults] setObject:[self.methodTextField stringValue] forKey:@"API_METHOD"];

    [(DOLAppDelegate *)[[NSApplication sharedApplication] delegate] windowWillClose];
    
    return YES;
}

@end
