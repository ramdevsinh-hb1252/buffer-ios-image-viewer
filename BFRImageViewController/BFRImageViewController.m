//
//  BFRImageViewController.m
//  Buffer
//
//  Created by Jordan Morgan on 11/13/15.
//
// CODE FROM CRC HERE

#import "BFRImageViewController.h"


@interface BFRImageViewController () <UIPageViewControllerDataSource, UIScrollViewDelegate>
@end

@implementation BFRImageViewController

#pragma mark - Initializers

- (instancetype)initWithImageSource:(NSArray *)images {
    self = [super init];
    
    if (self) {
        NSAssert(images.count > 0, @"You must supply at least one image source to use this class.");
        self.images = images;
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initForPeekWithImageSource:(NSArray *)images {
    self = [super init];
    
    if (self) {
        NSAssert(images.count > 0, @"You must supply at least one image source to use this class.");
        self.images = images;
        self.usedFor3DTouch = YES;
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit {
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.enableDoneButton = YES;
    self.showDoneButtonOnLeft = YES;
    self.disableAutoplayForLivePhoto = YES;
    self.parallaxView = [UIView new];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // View setup
    self.view.backgroundColor = self.isUsingTransparentBackground ? [UIColor clearColor] : [UIColor blackColor];

    // Prepare the UI
    [self reinitializeUI];
    
    // Register for touch events on the images/scrollviews to hide UI chrome
    [self registerNotifcations];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.hideStatusBar = YES;
    [UIView animateWithDuration:0.1 animations:^{
        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self updateChromeFrames];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        [[UIDevice currentDevice]setValue:@(UIInterfaceOrientationPortrait) forKey:@"orientation"];
    }
//    if UI_USER_INTERFACE_IDIOM() != .pad {
//        let value = UIInterfaceOrientation.portrait.rawValue
//        UIDevice.current.setValue(value, forKey: "orientation")
//    }
}

#pragma mark - Status bar

- (BOOL)prefersStatusBarHidden {
    if (self.presentingViewController.prefersStatusBarHidden) {
        return YES;
    }
    
    return self.shouldHideStatusBar;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationSlide;
}

#pragma mark - Accessors

- (void)setImageSource:(NSArray *)images {
    self.images = images;
    [self reinitializeUI];
}

- (NSInteger)currentIndex {
    return ((BFRImageContainerViewController *)self.pagerVC.viewControllers.firstObject).pageIndex;
}

#pragma mark - Chrome/UI

- (void)reinitializeUI {
    
    // Ensure starting index won't trap
    if (self.startingIndex >= self.images.count || self.startingIndex < 0) {
        self.startingIndex = 0;
    }
    
    if (!self.imageViewControllers) {
        // Set up pager
        if (!self.pagerVC) {
            self.pagerVC = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                           navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                         options:nil];
        }
        
        // Add pager to view hierarchy
        [self addChildViewController:self.pagerVC];
        [[self view] addSubview:[self.pagerVC view]];
        [self.pagerVC didMoveToParentViewController:self];
        
        // Attach to pager controller's scrollview for parallax effect when swiping between images
        for (UIView *subview in self.pagerVC.view.subviews) {
            if ([subview isKindOfClass:[UIScrollView class]]) {
                ((UIScrollView *)subview).delegate = self;
                self.parallaxView.backgroundColor = self.view.backgroundColor;
                self.parallaxView.hidden = YES;
                [subview addSubview:self.parallaxView];
                
                CGRect parallaxSeparatorFrame = CGRectZero;
                parallaxSeparatorFrame.size = [self sizeForParallaxView];
                self.parallaxView.frame = parallaxSeparatorFrame;
                
                break;
            }
        }
        
        // Add chrome to UI now if we aren't waiting to be peeked into
        if (!self.isBeingUsedFor3DTouch) {
            [self addChromeToUI];
        }
    }
    
    
    // Setup image view controllers
    self.imageViewControllers = [NSMutableArray new];
    for (id imgSrc in self.images) {
        BFRImageContainerViewController *imgVC = [BFRImageContainerViewController new];
        imgVC.imgSrc = imgSrc;
        imgVC.pageIndex = self.startingIndex;
        imgVC.usedFor3DTouch = self.isBeingUsedFor3DTouch;
        imgVC.useTransparentBackground = self.isUsingTransparentBackground;
        imgVC.disableSharingLongPress = self.shouldDisableSharingLongPress;
        imgVC.disableHorizontalDrag = (self.images.count > 1);
        imgVC.disableAutoplayForLivePhoto = self.shouldDisableAutoplayForLivePhoto;
        [self.imageViewControllers addObject:imgVC];
    }
    
    // Reset pager to the existing view controllers
    self.pagerVC.dataSource = self.imageViewControllers.count > 1 ? self : nil;
    [self.pagerVC setViewControllers:@[self.imageViewControllers[self.startingIndex]]
                           direction:UIPageViewControllerNavigationDirectionForward
                            animated:NO
                          completion:nil];
}

- (void)canRotate {
    
}

- (void)addChromeToUI {
    if (self.enableDoneButton) {
        NSBundle *bundle = [NSBundle bundleForClass:[BFRImageViewController class]];
        NSString *imagePath = [bundle pathForResource:@"cross" ofType:@"png"];
        UIImage *crossImage = [[UIImage alloc] initWithContentsOfFile:imagePath];

        self.doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.doneButton setAccessibilityLabel:BFRImageViewerLocalizedStrings(@"imageViewController.closeButton.text", @"Close")];
        [self.doneButton setImage:crossImage forState:UIControlStateNormal];
        [self.doneButton addTarget:self action:@selector(handleDoneAction) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:self.doneButton];
        [self.view bringSubviewToFront:self.doneButton];
        
        [self updateChromeFrames];
    }
}

- (void)updateChromeFrames {
    if (self.enableDoneButton) {
        CGFloat buttonX = self.showDoneButtonOnLeft ? 20 : CGRectGetMaxX(self.view.bounds) - 37;
        CGFloat closeButtonY = 20;
        
        if (@available(iOS 11.0, *)) {
            closeButtonY = self.view.safeAreaInsets.top > 0 ? self.view.safeAreaInsets.top : 20;
        }
        
        self.doneButton.frame = CGRectMake(buttonX, closeButtonY, 17, 17);
    }
    
    self.parallaxView.hidden = YES;
}

#pragma mark - Pager Datasource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSUInteger index = ((BFRImageContainerViewController *)viewController).pageIndex;
    
    if (index == 0) {
        return nil;
    }
    
    // Update index
    index--;
    BFRImageContainerViewController *vc = self.imageViewControllers[index];
    vc.pageIndex = index;
    
    return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSUInteger index = ((BFRImageContainerViewController *)viewController).pageIndex;
    
    if (index == self.imageViewControllers.count - 1) {
        return nil;
    }
    
    //Update index
    index++;
    BFRImageContainerViewController *vc = self.imageViewControllers[index];
    vc.pageIndex = index;
    
    return vc;
}

#pragma mark - Scrollview Delegate + Parallax Effect

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.parallaxView.hidden = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateParallaxViewFrame:scrollView];
}

- (void)updateParallaxViewFrame:(UIScrollView *)scrollView {
    CGRect bounds = scrollView.bounds;
    CGRect parallaxSeparatorFrame = self.parallaxView.frame;

    CGPoint offset = bounds.origin;
    CGFloat pageWidth = bounds.size.width;

    NSInteger firstPageIndex = floorf(CGRectGetMinX(bounds) / pageWidth);

    CGFloat x = offset.x - pageWidth * firstPageIndex;
    CGFloat percentage = x / pageWidth;

    parallaxSeparatorFrame.origin.x = pageWidth * (firstPageIndex + 1) - parallaxSeparatorFrame.size.width * percentage;

    self.parallaxView.frame = parallaxSeparatorFrame;
}

- (CGSize)sizeForParallaxView {
    CGSize parallaxSeparatorSize = CGSizeZero;
    
    parallaxSeparatorSize.width = PARALLAX_EFFECT_WIDTH * 2;
    parallaxSeparatorSize.height = self.view.bounds.size.height;
    
    return parallaxSeparatorSize;
}

#pragma mark - Utility methods

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void (^ __nullable)(void))completion {
    // If we dismiss from a different image than what was animated in - don't do the custom dismiss transition animation
    if (self.startingIndex != self.currentIndex) {
        [self dismissWithoutCustomAnimationWithCompletion:completion];
        return;
    }
    
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self dismissViewControllerAnimated:YES completion:completion];
}

- (void)dismissWithoutCustomAnimation {
    [self dismissWithoutCustomAnimationWithCompletion:nil];
}

- (void)dismissWithoutCustomAnimationWithCompletion:(void (^ __nullable)(void))completion {
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTE_VC_SHOULD_CANCEL_CUSTOM_TRANSITION object:@(1)];

    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self dismissViewControllerAnimated:YES completion:completion];
}

- (void)handlePop {
    self.view.backgroundColor = [UIColor blackColor];
    [self addChromeToUI];
}

- (void)handleDoneAction {
    [self dismissWithCompletion:nil];
}

/*! The images and scrollview are not part of this view controller, so instances of @c BFRimageContainerViewController will post notifications when they are touched for things to happen. */
- (void)registerNotifcations {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismiss) name:NOTE_VC_SHOULD_DISMISS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismiss) name:NOTE_IMG_FAILED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePop) name:NOTE_VC_POPPED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissWithoutCustomAnimation) name:NOTE_VC_SHOULD_DISMISS_FROM_DRAGGING object:nil];
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark - Memory Considerations

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"BFRImageViewer: Dismissing due to memory warning.");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
