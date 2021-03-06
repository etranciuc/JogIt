//
//  MenuViewController.m
//  RunnersCompass
//
//  Created by Geoff MacDonald on 2012-10-30.
//  Copyright (c) 2012 Geoff MacDonald. All rights reserved.
//

#import "Menu.h"


@implementation MenuViewController

@synthesize MenuTable;
@synthesize runInProgressAsFarAsICanTell;
@synthesize settingsBut,performanceBut,goalsBut,expandBut,collapseBut;
@synthesize expandState;
@synthesize delegate;

static NSString * dateCellID = @"DateCellPrototype";

#pragma mark -
#pragma mark View Lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //will regroup runs
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(regroupRuns)
                                                 name:@"groupingChangedNotification"
                                               object:nil];
    //change start cell image
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didReceivePause:)
                                                name:@"pauseToggleNotification" object:nil];
    
    if(!start)
    {
        StartCell * cell  =  [[[NSBundle mainBundle]loadNibNamed:@"StartCell"
                                                           owner:self
                                                         options:nil]objectAtIndex:0];
        [cell setup];
        [cell setDelegate:self];
        
        start = cell;
    }
    
    runs = [NSMutableArray new];
    cells = [NSMutableArray new];

    //find all runs
    NSArray * runRecords = [RunRecord MR_findAllSortedBy:@"date" ascending:false];
    
    //determine PRs here first
    for(RunRecord * runRecord in runRecords)
    {
        //init RunEvent with data
        RunEvent * eventToAdd = [[RunEvent alloc] initWithRecord:runRecord];
        
        [runs addObject:eventToAdd];
    }
    
    //determine PRs
    [self analyzePRs];
    
    runInProgressAsFarAsICanTell = false;
    
    //load cell
    [MenuTable registerClass:[DateCell class] forCellReuseIdentifier:dateCellID];
    UINib * nib = [UINib nibWithNibName:@"DateCell" bundle:[NSBundle mainBundle]] ;
    [MenuTable registerNib:nib forCellReuseIdentifier:dateCellID];
    
    //allow menu table to scroll to top
    [MenuTable setScrollsToTop:true];
    
    //disable collapse button since it will not do anything
    [collapseBut setEnabled:false];
    if([runs count] == 0)
        [expandBut setEnabled:false];
        
    
    expandState = 0;
    expandedCount = 0;
    showFirstRun = false;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

-(void)regroupRuns
{
    //scroll to prevent incorrect cell load
    [MenuTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:false];
    
    
    //delete all cells reload data
    [cells removeAllObjects];
    
    [MenuTable reloadData];
    
}

- (void)didReceivePause:(NSNotification *)notification
{
    //change image to record/pause
    runPausedAsFarAsICanTell = !runPausedAsFarAsICanTell;
    
    //disappear and reappear with fade
    if(runPausedAsFarAsICanTell)
    {
        [start.recordImage setImage:[UIImage imageNamed:@"whitepause.png"]];
    }
    else
    {
        [start.recordImage setImage:[UIImage imageNamed:@"record.png"]];
    }
    [AnimationUtil fadeView:start.recordImage duration:buttonFade toVisible:true];
    
}

#pragma mark -
#pragma mark PR management

-(void)analyzePRs
{
    furthestRun = nil;
    fastestRun = nil;
    caloriesRun = nil;
    longestRun = nil;
    
    for(RunEvent * oldRun in runs)
    {
        //check for PRs
        if(furthestRun)
        {
            if(furthestRun.distance < oldRun.distance)
            {
                furthestRun = oldRun;
            }
        }
        else
        {
            furthestRun = oldRun;
        }
        if(fastestRun)
        {   //special restriction for speed in case it's zero
            if(fastestRun.avgPace < oldRun.avgPace && oldRun.avgPace < maxSpeedForPR)
            {
                fastestRun = oldRun;
            }
        }
        else
        {
            fastestRun = oldRun;
        }
        if(caloriesRun)
        {
            if(caloriesRun.calories < oldRun.calories)
            {
                caloriesRun = oldRun;
            }
        }
        else
        {
            caloriesRun = oldRun;
        }
        if(longestRun)
        {
            if(longestRun.time < oldRun.time)
            {
                longestRun = oldRun;
            }
        }
        else
        {
            longestRun = oldRun;
        }
    }
}


#pragma mark -
#pragma mark Menu Table data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{

    CGFloat height = [start getHeightRequired];
    
    
    return height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if(section == 0)
    {
        if(!start)
        {
            StartCell * cell  =  [[[NSBundle mainBundle]loadNibNamed:@"StartCell"
                                                               owner:self
                                                             options:nil]objectAtIndex:0];
            [cell setDelegate:self];
            [cell setup];
            
            start = cell;
            
        }
        
        return start;
        
    }
    
    return nil;
    
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //get number of periods for runs
    UserPrefs * curPrefs = [self getPrefs];

    numPeriods = [Util numPeriodsForRuns:runs withWeekly:[[curPrefs weekly] boolValue]];
    
    return numPeriods;
}

// Customize the appearance of table view cells.
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];

    if(row >= [cells count]){
        
        
        //DateCell * cell = (DateCell * )[tableView dequeueReusableCellWithIdentifier:dateCellID];
        DateCell * cell = [[[NSBundle mainBundle]loadNibNamed:@"DateCell"owner:self options:nil] objectAtIndex:0];
        
        for(DateCell *oldCell in cells)
        {
            NSAssert(oldCell != cell, @"stale cell");
        }
        
        
        BOOL isWeekly = [[[self getPrefs] weekly] boolValue];
        
        [cells addObject:cell];
        [cell setDelegate:self];
        //determine runs to allocate
        [cell setPeriodStart:[Util dateForPeriod:row withWeekly:isWeekly]];
        [cell setRuns:[Util runsForPeriod:runs withWeekly:isWeekly withPeriodStart:cell.periodStart]];
        [cell setIndexForColor:row];
        [cell setWeekly:isWeekly];
        //all prefs are requested
        [cell setup];
        
        if(showFirstRun && row == 0)
        {
            [cell headerViewTap:nil];
            showFirstRun = false;
            
            [cell performSelector:@selector(openFirstRun) withObject:nil afterDelay:openFirstRunAfterDelay];
        }
        
        //NSLog(@"row %d requested - cache size: %d - creating %d...", row, [cells count], cell.indexForColor);
        
        return cell;
    }
    else{
        
        DateCell * curCell = [cells objectAtIndex:row];
        
        return curCell;
    } 
}

#pragma mark -
#pragma mark Menu Table delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height;
    NSUInteger row = [indexPath row];
    
    if(row >= [cells count]){
        
        //delay dequeueing, not to be done here for performance
        
        height = 64.0f;
    }
    else{
        
        DateCell * cell = [cells objectAtIndex:row];
        
        height = [cell getHeightRequired];
    }

    return height;
}

#pragma mark -
#pragma mark DateCellDelegate

-(void) cellDidChangeHeight:(id) sender byTouch:(BOOL)byTouch
{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"resetCellDeletionModeAfterTouch"
                                                        object:nil];
    
    //animate only if touched
    if(byTouch)
    {
        [MenuTable beginUpdates];
        [MenuTable endUpdates];
    }
    [MenuTable reloadData];
    
    //check if hierarchical cell expanded and changed accordingly
    //any change will something has collapsed
    if(expandState == 2 && byTouch)
    {
        expandState = 1;
        [collapseBut setEnabled:true];
        [expandBut setEnabled:true];
    }
    
    if([runs count] == 0)
        [expandBut setEnabled:false];

    
    //we will need to scroll to correct hierarchy cell if it is just off screen here
    
}


-(void)dateCellDidExpand:(BOOL)expand withRow:(NSInteger)row byTouch:(BOOL)byTouch
{
    if(expand)
    {
        expandedCount++;
    }
    else
    {
        expandedCount--;
        if(expandedCount < 0)
            expandedCount = 0;
    }
    
    if(expandState == 0)
    {
        if(expand)
        {
            expandState = 1;
            [collapseBut setEnabled:true];
            [expandBut setEnabled:true];
        }
    }
    else if(expandState == 2)
    {
        if(!expand)
        {
            expandState = 1;
            [collapseBut setEnabled:true];
            [expandBut setEnabled:true];
        }
    }
    else if(expandState == 1)
    {
        if(!expand && expandedCount == 0)
        {
            expandState = 0;
            [collapseBut setEnabled:false];
            [expandBut setEnabled:true];
        }
    }
    
    if([runs count] == 0)
        [expandBut setEnabled:false];
    
    //scroll to this cell if expanding
    if(expand && byTouch && row == [cells count] - 1)
        [MenuTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:true];
}

-(void)updateGestureFailForCell:(UIGestureRecognizer*)cellGesture
{
    
    [self.delegate updateGesturesNeededtoFail:cellGesture];
}

-(UserPrefs*)getPrefs
{
    UserPrefs * prefs = [self.delegate curUserPrefs];
    
    return prefs;
    
}

-(void)preventUserFromSlidingRunInvalid:(RunEvent*)runToInvalid
{
    [self.delegate preventUserFromSlidingRunInvalid:runToInvalid];
}

-(void)startDeleteRun
{
    //start loading indicator
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

-(void)didDeleteRun:(NSTimeInterval)runDate withCell:(id)datecell hideProgress:(BOOL)hideProg
{
    //hide loading indicator
    if(hideProg)
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    DateCell * cell = datecell;
    RunEvent * runToDelete;
    
    BOOL isWeekly = [[[self getPrefs] weekly] boolValue];
    
    for(RunEvent * oldRun in runs)
    {
        if([oldRun.date timeIntervalSinceReferenceDate] == runDate)
        {
            runToDelete = oldRun;
        }
    }
    if(runToDelete)
    {
        [runs removeObject:runToDelete];
        [self preventUserFromSlidingRunInvalid:runToDelete];
    }
    
    //see if the run was the only one left
    if([[cell runs] count] == 0)
    {
        NSMutableArray *arrayToDeleteCells = [NSMutableArray new];
        
        NSInteger cellIndex = [cells indexOfObject:cell];
        
        numPeriods = [Util numPeriodsForRuns:runs
                                            withWeekly:isWeekly];
        
        while(numPeriods <= cellIndex)
        {
            NSIndexPath * indexToDelete = [NSIndexPath indexPathForRow:cellIndex inSection:0];
            
            [arrayToDeleteCells addObject:indexToDelete];
            [cells removeLastObject];
            
            cellIndex--;
        
        }
        if([arrayToDeleteCells count])
            [MenuTable deleteRowsAtIndexPaths:arrayToDeleteCells withRowAnimation:UITableViewRowAnimationLeft];
    }
    
    if([runs count] == 0)
        [expandBut setEnabled:false];
    
    [self analyzePRs];
}

-(void)presentShareWithItems:(NSArray*)items
{
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark -
#pragma mark Start Cell Delegate

-(void)selectedRunInProgress:(BOOL)shouldDiscard
{
    //selected the headerview of start cell when run is in progress, slide back to logger
    [self.delegate selectedRunInProgress:shouldDiscard];

}

-(void)selectedNewRun:(RunEvent *) run
{
    [self cleanupForNav];
    
    //set logger with this run
    [self.delegate newRun:run animate:true];
    
    
    //modifiy header to indicate progressing run
    runInProgressAsFarAsICanTell = true;
    runPausedAsFarAsICanTell = true;
    [start.recordImage setHidden:false];
    //[start.timeLabel setHidden:false];
    start.headerLabel.text = NSLocalizedString(@"RunInProgressTitle", @"start cell title for runs in progress");
    [start setExpand:false withAnimation:true];
    start.locked = true;//to prevent expanding
    [start.garbageBut setHidden:false];
    [start.addRunButton setHidden:true];
    [start.folderImage setHidden:true];
    
}

#pragma mark -
#pragma mark Manual VC Delegate

-(void)manualRunToSave:(RunEvent*)runToSave
{
    if(runToSave)
    {
        //run saved to DB in manual VC
        
        //save usual way , same as with logger
        [self finishedRun:runToSave];
        
        //hide start cell
        [start setExpand:false withAnimation:true];
    }
}

-(void)manualRunCancelled
{
    //do nothing
}

#pragma mark -
#pragma mark Logger Interface with app delegate

//also heierachical cell delegate method
-(void)selectedRun:(id)sender
{
    [self cleanupForNav];
    
    //NSLog(@"Selected Run from Menu %f",[NSDate timeIntervalSinceReferenceDate]);
    
    if(!runInProgressAsFarAsICanTell)
    {
        HierarchicalCell * cell = (HierarchicalCell * )sender;
        
        //if associated is manual, don't load, just shake manual label
        if(cell.associatedRun.eventType ==EventTypeManual)
        {
            [AnimationUtil shakeView:cell.manualEntryLabel];
            //do not load
            return;
        }
        
        //if run is already loaded, slide to logger
        if([self.delegate isRunAlreadyLoaded:cell.associatedRun])
        {
            [self.delegate selectedRunInProgress:false];
            return;
        }
        
        //need to fetch real record and fill with data points
        RunRecord * recordToLoad = [RunRecord MR_findFirstByAttribute:@"date" withValue:cell.associatedRun.date];
        
        //only show progress if cell is big enough to justify
        if([[recordToLoad time] doubleValue] > loadTimeMinForProgress)
        {
            //lock slider before beginning load
            [self.delegate lockBeforeLoad];
            
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                
                //takes a long time
                RunEvent * runToLoad = [[RunEvent alloc] initWithRecordToLogger:recordToLoad];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    //set logger with this run
                    [self.delegate loadRun:runToLoad close:true];
                });
            });
        }
        else
        {
            RunEvent * runToLoad = [[RunEvent alloc] initWithRecordToLogger:recordToLoad];
            //set logger with this run
            [self.delegate loadRun:runToLoad close:true];
        }
        
        //refresh start cell
        runInProgressAsFarAsICanTell = false;
        [start.recordImage setHidden:true];
        //[start.timeLabel setHidden:true];
        [start.headerLabel setText:NSLocalizedString(@"StartRunTitle", @"Title for start cell")];
        start.locked = false;//to prevent expanding
        [start.garbageBut setHidden:true];
        [start.addRunButton setHidden:false];
        [start.folderImage setHidden:false];
    
    }
    else{
        //shake run in progress title
        [AnimationUtil shakeView:start.headerLabel];
    }
}

-(void) finishedRun:(RunEvent*)finishedRun
{
    
    //save run and add it to the menu if it exists
    if(finishedRun)
    {
        //determine index to insert run into since date can be different due to manual entry
        NSInteger indexToInsert = -1;
        //should be currently sorted such that highest (latest) date is at index 0
        for(int i = 0; i <  [runs count]; i++)
        {
            RunEvent * oldRun = [runs objectAtIndex:i];
            //until run to save is greater than old run
            if([oldRun.date timeIntervalSinceReferenceDate] > [finishedRun.date timeIntervalSinceReferenceDate])
            {
                indexToInsert = i;
            }
        }
        if(indexToInsert == -1)
        {
            //add to very top
            [runs insertObject:finishedRun atIndex:0];
            //to zoom on table path correctly
            indexToInsert = 0;
        }
        else if(indexToInsert == [runs count]-1)
        {
            //very end of list
            [runs addObject:finishedRun];
        }
        else
        {
            indexToInsert++;
            //insert at correct index
            [runs insertObject:finishedRun atIndex:indexToInsert];
        }
        
        //scroll to top
        [MenuTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:false];
        
        //enable expand/collapse
        [expandBut setEnabled:true];
    
        [cells removeAllObjects];
        [MenuTable reloadData];
        
        //expand first thing to show where it went if it was not manual
        if(finishedRun.eventType != EventTypeManual)
        {
            showFirstRun = true;
            [collapseBut setEnabled:true];
            
            if([runs count] == 1)
            {
                [expandBut setEnabled:false];
            }
        }
        else
        {
            [collapseBut setEnabled:false];
        }
        
        BOOL alreadyPresentedNotification = false;
        
        //display goal achieved notification regardless of manual or not
        Goal * curGoal = [self.delegate curGoal];
        //did new run cause goal to be complete and wasn't completed before hand
        if(curGoal.type != GoalTypeNoGoal)
        {
            //reprocess and new progress will be saved
            //need sorted runs
            NSMutableArray * runsToProcess = [[NSMutableArray alloc] initWithCapacity:[runs count]];
            
            //already sorted so that first object is latest date
            for(RunEvent * runToConsider in runs)
            {
                if(curGoal.endDate)
                {
                    if (([runToConsider.date compare:curGoal.startDate ] == NSOrderedDescending) &&
                        ([runToConsider.date compare:curGoal.endDate] == NSOrderedAscending))
                    {
                        [runsToProcess addObject:runToConsider];
                    }
                }
                else
                {
                    if ([runToConsider.date compare:curGoal.startDate ] == NSOrderedDescending)
                    {
                        [runsToProcess addObject:runToConsider];
                    }
                }
            }
            
            //run must be present in array otherwise , it's date is out of range
            if([runsToProcess count] > 0 && [runsToProcess containsObject:finishedRun])
            {
                //only if goal wasn't previously completed
                [runsToProcess removeObject:finishedRun];
                if(![curGoal processGoalForRuns:runsToProcess withMetric:[[[self.delegate curUserPrefs] metric] boolValue]])
                {
                    [runsToProcess addObject:finishedRun];
                    if([curGoal processGoalForRuns:runsToProcess withMetric:[[[self.delegate curUserPrefs] metric] boolValue]])
                    {
                        //present PR notification popup
                        GoalNotifyVC * vc = [[GoalNotifyVC alloc] initWithNibName:@"GoalNotifyVC" bundle:nil];
                        [vc.view setBackgroundColor:[Util redColour]];
                        [vc.view.layer setCornerRadius:5.0f];
                        [vc setPrefs:[self.delegate curUserPrefs]];
                        [vc setPrRun:finishedRun];
                        [vc setGoal:[self.delegate curGoal]];
                        
                        alreadyPresentedNotification = true;
                        [self presentPopupViewController:vc animationType:MJPopupViewAnimationSlideTopBottom];
                        [vc setLabels];
                    }
                }
            }
        }
        
        [self analyzePRs];
        
        //determine if a new PR was made, unless it was manual
        if(finishedRun.eventType != EventTypeManual)
        {
            
            //do not present notification if already popped up
            if(!alreadyPresentedNotification && ((finishedRun == longestRun) || (finishedRun == furthestRun)||(finishedRun == caloriesRun)||(finishedRun == fastestRun)))
            {
                
                //only present if run is meaningful, ie. don't show PR on run with 0.05km
                if(finishedRun.distance > PRMinDistanceRequirement)
                {
                    //present PR notification popup
                    NotificationVC * vc = [[NotificationVC alloc] initWithNibName:@"NotificationVC" bundle:nil];
                    [vc.view.layer setCornerRadius:5.0f];
                    [vc.view setBackgroundColor:[Util redColour]];
                    [vc setPrefs:[self.delegate curUserPrefs]];
                    [vc setPrRun:finishedRun];
                    //return yes if one of these runs if the checked
                    if(finishedRun == fastestRun)
                        [vc setType:MetricTypePace];
                    if (finishedRun == furthestRun)
                        [vc setType2:MetricTypeDistance];
                    if(finishedRun == caloriesRun)
                        [vc setType3:MetricTypeCalories];
                    if(finishedRun == longestRun)
                        [vc setType4:MetricTypeTime];
                    
                    [self presentPopupViewController:vc animationType:MJPopupViewAnimationSlideTopBottom];
                    [vc setPRLabels];
                }
            }
        }
    }
    
    //refresh start cell
    runInProgressAsFarAsICanTell = false;
    [start.recordImage setHidden:true];
    //[start.timeLabel setHidden:true];
    [start.headerLabel setText:NSLocalizedString(@"StartRunTitle", @"Title for start cell")];
    start.locked = false;//to prevent expanding
    [start.garbageBut setHidden:true];
    [start.addRunButton setHidden:false];
    [start.folderImage setHidden:false];
}

-(void)updateTimeString:(NSString *)updatedTimeString
{
    //update label
    //[start.timeLabel setText:updatedTimeString];
    
}

#pragma mark -
#pragma mark Action sheet delegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    //for discarding active run
    if(buttonIndex == 0)
    {
        //pass nil
        [self.delegate finishedRun:nil];
    }
}


#pragma mark -
#pragma mark Nav Bar Action

-(void)cleanupForNav
{
    //stuff to do before navigation like take down garbage cans
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"resetCellDeletionModeAfterTouch"
                                                        object:nil];
}
- (IBAction)performanceNavPressed:(id)sender {
    
    //nav bar cleanup
    [self cleanupForNav];
    
    //prepare analyze data
    Analysis * analysisToSet = [[Analysis alloc] analyzeWithRuns:runs withPurchase:true];//for now generate all data and only hide rows in performanceVC
    [analysisToSet setCaloriesRun:caloriesRun];
    [analysisToSet setFastestRun:fastestRun];
    [analysisToSet setFurthestRun:furthestRun];
    [analysisToSet setLongestRun:longestRun];
    
    PerformanceVC * vc = [[PerformanceVC alloc] initWithNibName:@"Performance" bundle:nil];
    [vc setAnalysis:analysisToSet];
    [vc setPrefs:[self.delegate curUserPrefs]];
    
    [self presentViewController:vc animated:true completion:nil];
}
- (IBAction)goalsNavPressed:(id)sender {
    
    //nav bar cleanup
    [self cleanupForNav];
    
    GoalsViewController * vc = [[GoalsViewController alloc] initWithNibName:@"Goals" bundle:nil];
    [vc setPrefs:[self.delegate curUserPrefs]];
    [vc setCurGoal:[self.delegate curGoal]];
    [vc setOriginalRunsSorted:runs];
    [self presentViewController:vc animated:true completion:nil];
}

- (IBAction)settingsNavPressed:(id)sender {
    
    //nav bar cleanup
    [self cleanupForNav];
    
    SettingsViewController * vc = [[SettingsViewController alloc] initWithNibName:@"Settings" bundle:nil];
    
    //set current settings
    [vc setPrefsToChange:[self.delegate curUserPrefs]];
    [self presentViewController:vc animated:true completion:nil];
}

- (IBAction)collapsePressed:(id)sender
{
    if(expandState == 2)
        [expandBut setEnabled:true];
    
    expandState--;
    if(expandState <= 0)
    {
        expandState = 0;
        //reset count in case it goes to infinite
        expandedCount = 0;
        
        //shade button
        [collapseBut setEnabled:false];
    }
    else if(expandState > 1)//must collapse something
    {
        expandState = 1;
    }
    
    if([runs count] == 0)
        [expandBut setEnabled:false];
    
    //collapse all cells
    for(DateCell * dateCell in cells)
    {
        [dateCell collapseAll:expandState];
    }
}

- (IBAction)expandPressed:(id)sender
{
    if(expandState == 0)
        [collapseBut setEnabled:true];
    
    expandState++;
    if(expandState >= 2)
    {
        expandState = 2;
        
        //shade button here in future
        [expandBut setEnabled:false];
    }
    else if(expandState < 1)//has to at least expand something
    {
        expandState = 1;
    }
    
    //expand all cells
    for(DateCell * dateCell in cells)
    {
        [dateCell expandAll:expandState];
    }
}

#pragma mark -
#pragma mark StartCell Actions

-(void)paceRunStart:(NSNumber*)selectedIndex
{
    CGFloat pace = [selectedIndex integerValue]; //s/km or s/mi
    
    //need m/s
    pace = 1000 / pace;
    
    //convert to imperial if neccessary
    UserPrefs * curPrefs = [self.delegate curUserPrefs];
    if(![curPrefs.metric boolValue])
    {
        pace = pace / convertKMToMile;
    }
    
    RunEvent * new = [[RunEvent alloc] initWithTarget:MetricTypePace withValue:pace withMetric:[curPrefs.metric boolValue] showSpeed:[curPrefs.showSpeed boolValue]];
    
    [self selectedNewRun:new];
    
}
-(void)distanceRunStart:(NSNumber*)selectedIndex
{
    CGFloat distance = 0.5 + ([selectedIndex intValue] * 0.5);
    
    //convert to mi or km
    UserPrefs * curPrefs = [self.delegate curUserPrefs];
    if(![curPrefs.metric boolValue])
    {
        distance = distance / convertKMToMile;
    }
    
    RunEvent * new = [[RunEvent alloc] initWithTarget:MetricTypeDistance withValue:distance*1000 withMetric:[[[self.delegate curUserPrefs] metric] boolValue] showSpeed:[[[self.delegate curUserPrefs] showSpeed] boolValue]];
    
    [self selectedNewRun:new];
    
}
-(void)timeRunStart:(NSNumber*)selectedIndex
{
    NSTimeInterval time = ([selectedIndex intValue] * 60);
    
    RunEvent * new = [[RunEvent alloc] initWithTarget:MetricTypeTime withValue:time withMetric:[[[self.delegate curUserPrefs] metric] boolValue] showSpeed:[[[self.delegate curUserPrefs] showSpeed] boolValue]];
    
    [self selectedNewRun:new];
    
}
-(void)caloriesRunStart:(NSNumber*)selectedIndex
{
    CGFloat calories = 25 + ([selectedIndex intValue] * 25);
    
    RunEvent * new = [[RunEvent alloc] initWithTarget:MetricTypeCalories withValue:calories withMetric:[[[self.delegate curUserPrefs] metric] boolValue] showSpeed:[[[self.delegate curUserPrefs] showSpeed] boolValue]];
    
    [self selectedNewRun:new];
    
}
-(void)justGoStart
{
    
    RunEvent * new = [[RunEvent alloc] initWithNoTarget];
    
    [self selectedNewRun:new];
    
}
- (IBAction)paceTapped:(id)sender {
    PacePicker *pace = [[PacePicker alloc] initWithTitle:[NSString stringWithFormat:@"Pace (min/%@)", [[self.delegate curUserPrefs] getDistanceUnit]]  rows:nil initialSelection:0 target:self successAction:@selector(paceRunStart:) cancelAction:@selector(actionPickerCancelled:) origin:sender];

    UserPrefs * curPrefs = [self.delegate curUserPrefs];
    
    //need PR in s/km form
    NSNumber * pRValue = [NSNumber numberWithInt:0];//1 min
    if(fastestRun)
    {
        if(fastestRun.avgPace >= 1.38889) //12 min/km minimum speed
        {
            CGFloat sKmSpeed = 1000 / fastestRun.avgPace; //convert to s/km from m/s
            if(![curPrefs.metric boolValue])
            {
                //convert to imperial if neccessary
                sKmSpeed = sKmSpeed * convertKMToMile;
            }
            //in s/km or s/mi 
            pRValue = [NSNumber numberWithInt:sKmSpeed];
        }
        else
            pRValue = [NSNumber numberWithInt:0];//0m 01s
    }
    //[pace addCustomButtonWithTitle:@"PR" value:pRValue];
    
    [pace showRunFormPicker];
    
}
- (IBAction)timeTapped:(id)sender {
    
    TimePicker *time = [[TimePicker alloc] initWithTitle:@"Time" rows:nil initialSelection:0 target:self successAction:@selector(timeRunStart:) cancelAction:@selector(actionPickerCancelled:) origin:sender];
    
    NSNumber * pRValue = [NSNumber numberWithInt:0];//1 min
    if(longestRun)
    {
        if(longestRun.time >= 60)
            pRValue = [NSNumber numberWithInt:(longestRun.time/60)];//+1 min above cur PR
        else
            pRValue = [NSNumber numberWithInt:0];//1 min
    }
    //[time addCustomButtonWithTitle:@"PR" value:pRValue];
    
    [time showRunFormPicker];
}

- (IBAction)calorieTapped:(id)sender {
    CaloriePicker *cal = [[CaloriePicker alloc] initWithTitle:@"Calories" rows:nil initialSelection:0 target:self successAction:@selector(caloriesRunStart:) cancelAction:@selector(actionPickerCancelled:) origin:sender];
    
    NSNumber * pRValue = [NSNumber numberWithInt:0];//25 cal
    if(caloriesRun)
    {
        if(caloriesRun.calories <= 2525)
            pRValue = [NSNumber numberWithInt:(caloriesRun.calories/25)];//+25 above current PR
        else
            pRValue = [NSNumber numberWithInt:(2525/25)]; //2500 cal
    }
    //[cal addCustomButtonWithTitle:@"PR" value:pRValue];
    
    [cal showRunFormPicker];
}

- (IBAction)distanceTapped:(id)sender {
    
    
    DistancePicker *distance = [[DistancePicker alloc] initWithTitle:[NSString stringWithFormat:@"Distance (%@)", [[self.delegate curUserPrefs] getDistanceUnit]] rows:nil initialSelection:0 target:self successAction:@selector(distanceRunStart:) cancelAction:@selector(actionPickerCancelled:) origin:sender];
    NSNumber * pRValue = [NSNumber numberWithInt:0];//1 min
    if(furthestRun)
    {
        if(furthestRun.distance >= 500)//500 m min since 1st selection is 0.5km
            pRValue = [NSNumber numberWithInt:furthestRun.distance/500];//+0.5km above cur PR
        else
            pRValue = [NSNumber numberWithInt:0];//500m
    }
    //[distance addCustomButtonWithTitle:@"PR" value:pRValue];
    
    [distance showRunFormPicker];
}

- (IBAction)manualTapped:(id)sender {
    
    //goto manual VC
    
    //nav bar cleanup
    [self cleanupForNav];
    
    ManualVC * vc = [[ManualVC alloc] initWithNibName:@"Manual" bundle:nil];
    
    //set current settings
    [vc setPrefs:[self.delegate curUserPrefs]];
    [vc setDelegate:self]; 
    [self presentViewController:vc animated:true completion:nil];
    
    //do not dismiss start cell
    
}

- (IBAction)justGoTapped:(id)sender {
    
    [self justGoStart];
}




@end
