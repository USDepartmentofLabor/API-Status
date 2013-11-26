//
//  DOLAppDelegate.h
//  API Status
//
//  Created by Michael Pulsifer on 11/19/13.
//
//  Released to the public domain

#import <Cocoa/Cocoa.h>
#import "GOVDataContext.h"
#import "GOVDataRequest.h"

@class APIPrefsWindowController;

@interface DOLAppDelegate : NSObject <NSApplicationDelegate, GOVDataRequestDelegate> {
    NSArray *arrayOfResults;
    NSDictionary *dictionaryOfResults;
    
    GOVDataRequest *dataRequest;
    
    IBOutlet NSMenuItem *preferencesMenuItem;

}

@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *preferencesMenuItem;
@property (nonatomic, strong) APIPrefsWindowController *windowController;

@property (nonatomic)NSArray *arrayOfResults;
@property (nonatomic)GOVDataRequest *dataRequest;
@property (nonatomic)NSDictionary *dictionaryOfResults;

-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithError:(NSString *)error;
-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithResults:(NSArray *)resultsArray andResponseTime:(float)timeInMS;
-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithDictionaryResults:(NSArray *)resultsDictionary andResponseTime:(float)timeInMS;
-(void)govDataRequest:(GOVDataRequest *)request didCompleteWithUnParsedResults:(NSString *)resultsString andResponseTime:(float)timeInMS;

-(void)updateMeter:(float)timeInMS;

-(void)submitRequest;
-(IBAction)onHandlePrefs:(id) sender;
-(void)windowWillClose;

@end
