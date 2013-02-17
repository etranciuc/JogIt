//
//  ChartCell.h
//  RunnersCompass
//
//  Created by Geoff MacDonald on 2013-02-16.
//  Copyright (c) 2013 Geoff MacDonald. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChartViewController.h"

@protocol ChartCellDelegate <NSObject>

-(void)cellDidChangeHeight:(id) sender;

@end

@interface ChartCell : UITableViewCell<CPTPlotDataSource>
{
@private
    CPTXYGraph *barChart;
}


//UI connections

@property (strong, nonatomic) IBOutlet CPTGraphHostingView *expandedView;

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIImageView *folderImage;
@property (weak, nonatomic) IBOutlet UILabel *headerLabel;



//delegate
@property (weak, nonatomic) id <ChartCellDelegate>delegate;


//instance variables
@property BOOL expanded;//for whether currently expanded
@property (nonatomic, setter = setAssociated:) ChartViewController * associated;

-(CGFloat)getHeightRequired;
-(void)setExpand:(BOOL)open withAnimation:(BOOL) animate;
-(void)setup;
- (IBAction)expandTapped:(id)sender;
- (IBAction)headerTapped:(id)sender;

@end