
// NSOperation-WebFetches-MadeEasy (TM)
// Copyright (C) 2012 by David Hoerl
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "MyViewController.h"

#import "WebFetcher.h"
// 3) Add the header to the implementation file
#import "OperationsRunner.h"
#import "OperationsRunnerProtocol.h"


@interface MyViewController () <OperationsRunnerProtocol>

@end

// 2) Add the protocol to the class extension interface in the implementation
@implementation MyViewController
{
	IBOutlet UIButton *fetch;
	IBOutlet UIButton *cancel;
	IBOutlet UIButton *back;
	IBOutlet UISlider *operationCount;
	IBOutlet UILabel *operationsToRun;
	IBOutlet UILabel *operationsLeft;
	IBOutlet UIActivityIndicatorView *spinner;

	// 1) Add either a property or an ivar to the implementation file
	OperationsRunner *operationsRunner;

}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
- (void)dealloc
{
	[self cancelOperations];	// good idea but not required
	
	NSLog(@"Dealloc done!");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self defaultButtons];
}

- (void)defaultButtons
{
	[self disable:NO control:fetch];
	[self disable:YES control:cancel];
	[self disable:NO control:operationCount];
	[self disable:NO control:fetch];
	[spinner stopAnimating];

	operationsToRun.text = [NSString stringWithFormat:@"%ld", lrintf([operationCount value]) ];
	operationsLeft.text = @"0";
}

- (IBAction)fetchAction:(id)sender
{
	[self disable:YES control:fetch];
	[self disable:NO control:cancel];
	[self disable:YES control:operationCount];
	[self disable:YES control:fetch];
	[spinner startAnimating];

	NSUInteger count = lrintf([operationCount value]);
	operationsLeft.text = [NSString stringWithFormat:@"%ld", count];
	for(int i=0; i<count; ++i) {
		NSString *msg = [NSString stringWithFormat:@"WebFetcher #%d", i];
		WebFetcher *fetcher = [WebFetcher new];
		fetcher.urlStr = @"http://dl.dropbox.com/u/60414145/Shed.jpg";
		fetcher.runMessage = msg;
		
		[self runOperation:fetcher withMsg:msg];
	
	}
}
- (IBAction)cancelAction:(id)sender
{
	[self cancelOperations];
	
	[self defaultButtons];
}

- (IBAction)backAction:(id)sender
{
	[self cancelOperations];	// good idea to do as soon as possible

	[self dismissViewControllerAnimated:YES completion:^{ ; }];
}

- (IBAction)operationsAction:(id)sender
{
	operationsToRun.text = [NSString stringWithFormat:@"%ld", lrintf([(UISlider *)sender value]) ];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)disable:(BOOL)disable control:(UIControl *)control
{
	control.enabled = !disable;
	control.alpha	= disable ? 0.50f : 1.0f;
}
	
- (void)operationFinished:(NSOperation *)op
{
	operationsLeft.text = [NSString stringWithFormat:@"%ld", [self operationsCount] ];
	
	WebFetcher *fetcher = (WebFetcher *)op;
	
	NSLog(@"Operation Completed: %@", fetcher.runMessage);
	
	if(![self operationsCount]) {
		[self defaultButtons];
	}
}

// 4) Add this method to the implementation file
- (id)forwardingTargetForSelector:(SEL)sel
{
	if(
		sel == @selector(runOperation:withMsg:)	|| 
		sel == @selector(operationsSet)			|| 
		sel == @selector(operationsCount)		||
		sel == @selector(cancelOperations)		||
		sel == @selector(enumerateOperations:)
	) {
		if(!operationsRunner) {
			// Object only created if needed
			operationsRunner = [[OperationsRunner alloc] initWithDelegate:self];
		}
		return operationsRunner;
	} else {
		return [super forwardingTargetForSelector:sel];
	}
}

- (void)viewDidUnload {
	spinner = nil;
	[super viewDidUnload];
}
@end

