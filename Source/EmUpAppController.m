/* Copyright (c) 2009 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  EmUpAppController.m
//

#import "GTMHTTPFetcherLogging.h"

#import "EmUpAppController.h"
#import "EmUpWindowController.h"

@interface EmUpAppController (PrivateMethods)
- (void)checkVersion;
@end

@implementation EmUpAppController

- (void)applicationWillFinishLaunching:(NSNotification *)notifcation {

  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController showWindow:self];

  [self checkVersion];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  return [windowController canAppQuitNow] ? NSTerminateNow : NSTerminateLater;
}

- (void)applicationWillTerminate:(NSNotification *)note {
  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController deleteImportedEntourageArchive];
}

#pragma mark -

- (IBAction)showHelp:(id)sender {
  NSString *urlStr = @"http://code.google.com/p/google-email-uploader-mac/";
  NSURL *url = [NSURL URLWithString:urlStr];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)showReleaseNotes:(id)sender {
  NSString *urlStr = @"http://google-email-uploader-mac.googlecode.com/svn/trunk/Source/ReleaseNotes.txt";
  NSURL *url = [NSURL URLWithString:urlStr];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)importFromEntourage:(id)sender {
  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController importRGEArchiveFromEntourage:sender];
}

- (IBAction)addMailboxes:(id)sender {
  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController addMailboxes:sender];
}

- (IBAction)reloadMailboxes:(id)sender {
  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController reloadMailboxesClicked:sender];
}

- (IBAction)loggingCheckboxClicked:(id)sender {
  // toggle the menu item's checkmark
  [loggingMenuItem_ setState:![loggingMenuItem_ state]];
  [GTMHTTPFetcher setLoggingEnabled:[loggingMenuItem_ state]];
}

- (IBAction)simulateUploadsClicked:(id)sender {
  [simulateUploadsMenuItem_ setState:![simulateUploadsMenuItem_ state]];

  EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];
  [windowController setSimulateUploads:[simulateUploadsMenuItem_ state]];
}

#pragma mark -

// we'll check the version in our plist against the plist on the open
// source site
//
// for testing, use
//   defaults write com.google.EmailUploader ForceUpdate "1"
//
- (void)checkVersion {
  NSString *const kLastCheckDateKey = @"LastVersionCheck";
  NSString *const kForceUpdateKey = @"ForceUpdate";
  NSString *const kSkipUpdateCheckKey = @"SkipUpdateCheck";

  // determine if we've checked in the last 24 hours (or if the the preferences
  // to force or skip an update are set)
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL shouldSkipUpdate = [defaults boolForKey:kSkipUpdateCheckKey];
  if (shouldSkipUpdate) return;

  NSDate *lastCheckDate = [defaults objectForKey:kLastCheckDateKey];
  BOOL shouldForceUpdate = [defaults boolForKey:kForceUpdateKey];
  if (lastCheckDate && !shouldForceUpdate) {
    // if the time since the last check is under a day, bail
    NSTimeInterval interval = - [lastCheckDate timeIntervalSinceNow];
    if (interval < 24 * 60 * 60) {
      return;
    }
  }

  // set the last check date to now
  [defaults setObject:[NSDate date]
               forKey:kLastCheckDateKey];

  // URL of our plist file in the sources online
  NSString *urlStr = @"http://google-email-uploader-mac.googlecode.com/svn/trunk/Source/LatestVersion.plist";

  GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithURLString:urlStr];
  [fetcher setComment:@"plist fetch"];
  [fetcher beginFetchWithDelegate:self
                didFinishSelector:@selector(plistFetcher:finishedWithData:error:)];

  [fetcher setUserData:[NSNumber numberWithBool:shouldForceUpdate]];
}

- (NSString *)appVersionForCurrentSystemVersionWithMap:(NSDictionary *)versionMap {
  // using a dictionary mapping system version ranges to app versions, like
  //  -10.4.11     : 1.1.2
  //  10.5-10.5.8  : 1.1.3
  //  10.6-        : 1.1.4
  // find the latest app version for the current system
  //
  // note: the system ranges should have no holes or overlapping system
  //       versions, and should not be order-dependent

  SInt32 systemMajor = 0, systemMinor = 0, systemRelease = 0;
  (void) Gestalt(gestaltSystemVersionMajor, &systemMajor);
  (void) Gestalt(gestaltSystemVersionMinor, &systemMinor);
  (void) Gestalt(gestaltSystemVersionBugFix, &systemRelease);

  NSString *systemVersion = [NSString stringWithFormat:@"%d.%d.%d",
                             (int)systemMajor, (int)systemMinor, (int)systemRelease];
  for (NSString *versionRange in versionMap) {

    NSString *lowSystemVersion = nil;
    NSString *dash = nil;
    NSString *highSystemVersion = nil;
    NSComparisonResult comp1, comp2;

    // parse "low", "low-", "low-high", or "-high"
    NSScanner *scanner = [NSScanner scannerWithString:versionRange];
    [scanner scanUpToString:@"-" intoString:&lowSystemVersion];
    [scanner scanString:@"-" intoString:&dash];
    [scanner scanUpToString:@"\r" intoString:&highSystemVersion];

    BOOL doesMatchLow = YES;
    BOOL doesMatchHigh = YES;

    if (lowSystemVersion) {
      comp1 = [GDataUtilities compareVersion:lowSystemVersion
                                   toVersion:systemVersion];
      doesMatchLow = (comp1 == NSOrderedSame
                      || (dash != nil && comp1 == NSOrderedAscending));
    }

    if (highSystemVersion) {
      comp2 = [GDataUtilities compareVersion:highSystemVersion
                                   toVersion:systemVersion];
      doesMatchHigh = (comp2 == NSOrderedSame
                       || (dash != nil && comp2 == NSOrderedDescending));
    }

    if (doesMatchLow && doesMatchHigh) {
      NSString *result = [versionMap objectForKey:versionRange];
      return result;
    }
  }

  return nil;
}

- (void)plistFetcher:(GTMHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data
               error:(NSError *)error {
  if (error) {
    // nothing to do but report this on the console
    NSLog(@"unable to fetch plist at %@, %@", [[fetcher mutableRequest] URL], error);
    return;
  }

  // convert the returns data to a plist dictionary
  NSString *errorStr = nil;
  NSDictionary *plist;

  plist = [NSPropertyListSerialization propertyListFromData:data
                                           mutabilityOption:NSPropertyListImmutable
                                                     format:NULL
                                           errorDescription:&errorStr];

  if ([plist isKindOfClass:[NSDictionary class]]) {

    // get the map of system versions to app versions, and step through the
    // system version ranges to find the latest app version for this system
    NSString *latestVersion;
    NSDictionary *versionMap = [plist objectForKey:@"SystemToVersionMap"];
    if (versionMap) {
      // new, with the map
      latestVersion = [self appVersionForCurrentSystemVersionWithMap:versionMap];
    } else {
      // old, without the map
      latestVersion = [plist objectForKey:@"CFBundleShortVersionString"];
    }

    // compare the short version string in this bundle to the one from the
    // map
    NSString *thisVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    NSComparisonResult result = [GDataUtilities compareVersion:thisVersion
                                                     toVersion:latestVersion];

    BOOL shouldForceUpdate = [[fetcher userData] boolValue];

    if (result != NSOrderedAscending && !shouldForceUpdate) {
      // we're current; do nothing
    } else {
      // show the user the "update now?" dialog
      EmUpWindowController* windowController = [EmUpWindowController sharedEmUpWindowController];

      NSString *title = NSLocalizedString(@"UpdateAvailable", nil);
      NSString *msg = NSLocalizedString(@"UpdateAvailableMsg", nil);
      NSString *updateBtn = NSLocalizedString(@"UpdateButton", nil); // "Update Now"
      NSString *dontUpdateBtn = NSLocalizedString(@"DontUpdateButton", nil); // "Don't Update"
      NSString *releaseNotesBtn = NSLocalizedString(@"ReleaseNotesButton", nil); // "Release Notes"

      NSBeginAlertSheet(title, updateBtn, dontUpdateBtn, releaseNotesBtn,
                        [windowController window], self,
                        @selector(updateSheetDidEnd:returnCode:contextInfo:),
                        nil, nil, msg, thisVersion, latestVersion);
    }
  } else {
    NSLog(@"unable to parse plist, %@", errorStr);
  }
}

- (void)updateSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {

  NSString *urlStr = nil;
  if (returnCode == NSAlertDefaultReturn) {
    // downloads page
    urlStr = @"https://code.google.com/p/google-email-uploader-mac/downloads/list";
  } else if (returnCode == NSAlertOtherReturn) {
    // release notes file in the source tree
    urlStr = @"http://code.google.com/p/google-email-uploader-mac/source/browse/trunk/Source/ReleaseNotes.txt";
  }

  if (urlStr) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlStr]];
  }
}

@end
