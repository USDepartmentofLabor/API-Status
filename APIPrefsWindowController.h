//
//  APIPrefsWindowController.h
//  API Status
//
//  Created by Michael Pulsifer on 11/22/13.
//
//  Released to the public domain

#import <Cocoa/Cocoa.h>

@interface APIPrefsWindowController : NSWindowController <NSWindowDelegate> {
    IBOutlet NSTextField *keyTextField;
    IBOutlet NSTextField *hostTextField;
    IBOutlet NSTextField *urlTextField;
    IBOutlet NSTextField *methodTextField;
    
}

@property (nonatomic, strong) IBOutlet NSTextField *keyTextField;
@property (nonatomic, strong) IBOutlet NSTextField *hostTextField;
@property (nonatomic, strong) IBOutlet NSTextField *urlTextField;
@property (nonatomic, strong) IBOutlet NSTextField *methodTextField;


@end
