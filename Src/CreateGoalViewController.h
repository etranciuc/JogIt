//
//  CreateGoalViewController.h
//  RunnersCompass
//
//  Created by Geoff MacDonald on 2013-02-17.
//  Copyright (c) 2013 Geoff MacDonald. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CreateGoalHeaderCell.h"
#import "Goal.h"
#import "UserPrefs.h"

@interface CreateGoalViewController : UITableViewController<UITableViewDataSource,UITableViewDelegate,UIActionSheetDelegate>

@property CreateGoalHeaderCell * header;
@property Goal *goal;
@property UserPrefs * prefs;
@property Goal * tempGoal;

@property (weak) IBOutlet UITableView *table;

@end
