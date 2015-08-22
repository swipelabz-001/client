//
//  KBEnvSelectView.m
//  Keybase
//
//  Created by Gabriel on 4/10/15.
//  Copyright (c) 2015 Gabriel Handford. All rights reserved.
//

#import "KBEnvSelectView.h"

#import "KBButtonView.h"
#import "KBEnvironment.h"
#import "KBHeaderLabelView.h"
#import "KBCustomEnvView.h"
#import "KBWorkspace.h"

#import "KBService.h"
#import "KBFSService.h"
#import "KBInstaller.h"

#import <KBAppKit/KBAppKit.h>

@interface KBEnvSelectView ()
@property KBSplitView *splitView;
@property KBListView *listView;
@property KBCustomEnvView *customView;
@end

@implementation KBEnvSelectView

- (void)viewInit {
  [super viewInit];
  [self kb_setBackgroundColor:KBAppearance.currentAppearance.backgroundColor];

  KBLabel *header = [[KBLabel alloc] init];
  [header setText:@"Choose an Environment" style:KBTextStyleHeaderLarge alignment:NSCenterTextAlignment lineBreakMode:NSLineBreakByTruncatingTail];
  [self addSubview:header];

  _splitView = [[KBSplitView alloc] init];
  _splitView.dividerPosition = 300;
  _splitView.divider.hidden = YES;
  _splitView.rightInsets = UIEdgeInsetsMake(0, 20, 0, 0);
  [self addSubview:_splitView];

  GHWeakSelf gself = self;
  _listView = [KBListView listViewWithPrototypeClass:KBImageTextCell.class rowHeight:0];
  _listView.scrollView.borderType = NSBezelBorder;
  _listView.onSet = ^(KBImageTextView *label, KBEnvironment *env, NSIndexPath *indexPath, NSTableColumn *tableColumn, KBListView *listView, BOOL dequeued) {
    [label setTitle:env.config.title info:env.config.info image:env.config.image lineBreakMode:NSLineBreakByClipping];
  };
  _listView.onSelect = ^(KBTableView *tableView, KBTableSelection *selection) {
    [gself select:selection.object];
  };
  [_splitView setLeftView:_listView];

  YOHBox *buttons = [YOHBox box:@{@"horizontalAlignment": @"center", @"spacing": @(10)}];
  [self addSubview:buttons];
  KBButton *closeButton = [KBButton buttonWithText:@"Quit" style:KBButtonStyleDefault];
  closeButton.targetBlock = ^{ [NSApp terminate:0]; };
  [buttons addSubview:closeButton];
  KBButton *nextButton = [KBButton buttonWithText:@"Next" style:KBButtonStylePrimary];
  nextButton.targetBlock = ^{ [gself next]; };
  [buttons addSubview:nextButton];

  self.viewLayout = [YOVBorderLayout layoutWithCenter:_splitView top:@[header] bottom:@[buttons] insets:UIEdgeInsetsMake(20, 40, 20, 40) spacing:20];

  _customView = [[KBCustomEnvView alloc] init];

  NSArray *envs = @[
                    [[KBEnvironment alloc] initWithConfig:[KBEnvConfig envType:KBEnvTypeProd]],
                    [[KBEnvironment alloc] initWithConfig:[KBEnvConfig envType:KBEnvTypeDevel]],
                    [[KBEnvironment alloc] initWithConfig:[KBEnvConfig envType:KBEnvTypeBrew]],
                    [[KBEnvironment alloc] initWithConfig:[KBEnvConfig loadFromUserDefaults:[KBWorkspace userDefaults]]],
                    ];
  [_listView setObjects:envs animated:NO];

  NSString *title = [[KBWorkspace userDefaults] objectForKey:@"Env"];
  KBEnvironment *selected = [envs detect:^BOOL(KBEnvironment *e) { return [e.config.title isEqualToString:title]; }];
  if (selected) [_listView setSelectedRow:[envs indexOfObject:selected]];
  else [_listView setSelectedRow:[_listView.dataSource countForSection:0] - 1];
}

- (void)select:(KBEnvironment *)environment {
  [_splitView setRightView:[self viewForEnvironment:environment]];
}

- (void)next {
  KBEnvironment *env = _listView.selectedObject;

  NSUserDefaults *userDefaults = [KBWorkspace userDefaults];
  [userDefaults setObject:env.config.title forKey:@"Env"];
  [userDefaults synchronize];

  if (env.config.envType == KBEnvTypeCustom) {
    KBEnvConfig *config = [_customView config];
    [config saveToUserDefaults:[KBWorkspace userDefaults]];
    NSError *error = nil;
    if (![config validate:&error]) {
      [KBActivity setError:error sender:self];
      return;
    }
    self.onSelect([[KBEnvironment alloc] initWithConfig:config]);
  } else if (env.config.envType == KBEnvTypeProd) {
    [KBActivity setError:KBMakeError(KBErrorCodeUnsupported, @"Not supported yet") sender:self];
  } else {
    self.onSelect(env);
  }
}

- (void)uninstall {
  KBEnvironment *env = _listView.selectedObject;
  KBInstaller *installer = [[KBInstaller alloc] init];
  [KBAlert yesNoWithTitle:@"Uninstall" description:NSStringWithFormat(@"Are you sure you want to uninstall %@?", env.config.title) yes:@"Uninstall" view:self completion:^(BOOL yes) {
    [installer uninstallWithEnvironment:env completion:^(NSArray *uninstallActions) {
      NSArray *errors = [uninstallActions select:^BOOL(KBInstallAction *uninstallAction) { return !!uninstallAction.error; }];
      if ([errors count] > 0) {
        [KBActivity setError:KBErrorAlert(@"There was an error uninstalling.") sender:self];
      }
    }];
  }];
}

- (NSView *)viewForEnvironment:(KBEnvironment *)environment {
  if (environment.config.envType == KBEnvTypeCustom) {
    [_customView setConfig:environment.config];
    return _customView;
  }

  YOVBox *view = [YOVBox box:@{@"spacing": @(10), @"insets": @(10)}];
  [view kb_setBackgroundColor:KBAppearance.currentAppearance.secondaryBackgroundColor];

  YOVBox *labels = [YOVBox box:@{@"spacing": @(10), @"insets": @"10,0,10,0"}];
  [view addSubview:labels];

  typedef NSView * (^KBCreateEnvInfoLabel)(NSString *key, NSString *value);

  KBCreateEnvInfoLabel createView = ^NSView *(NSString *key, NSString *value) {
    KBHeaderLabelView *view = [KBHeaderLabelView headerLabelViewWithHeader:key headerOptions:0 text:value style:KBTextStyleDefault options:0 lineBreakMode:NSLineBreakByCharWrapping];
    view.columnWidth = 120;
    return view;
  };

  KBEnvConfig *config = environment.config;
  if (config.host) [labels addSubview:createView(@"Host", config.host)];
  if (config.mountDir) [labels addSubview:createView(@"Mount", [KBPath path:config.mountDir options:KBPathOptionsTilde])];
  if (config.isLaunchdEnabled) {
    [labels addSubview:createView(@"Service Launchd", config.launchdLabelService)];
    [labels addSubview:createView(@"KBFS Launchd", config.launchdLabelKBFS)];
  }

  if (!config.isInstallEnabled) {
    [labels addSubview:createView(@" ", @"Installer Disabled")];
  }

  GHWeakSelf gself = self;
  YOHBox *buttons = [YOHBox box];
  [view addSubview:buttons];
  [buttons addSubview:[KBButton buttonWithText:@"Uninstall" style:KBButtonStyleDefault options:KBButtonOptionsToolbar targetBlock:^{ [gself uninstall]; }]];

  return view;
}

@end
