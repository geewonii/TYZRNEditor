#import "WPLegacyEditorViewController.h"
#import "WPLegacyKeyboardToolbarBase.h"
#import "WPLegacyKeyboardToolbarDone.h"
//#import <WordPressComAnalytics/WPAnalytics.h>
//#import <WordPressShared/WPStyleGuide.h>
//#import <WordPressShared/WPTableViewCell.h>
//#import <WordPressShared/UIImage+Util.h>

CGFloat const WPLegacyEPVCTextfieldHeight = 44.0f;
CGFloat const WPLegacyEPVCOptionsHeight = 44.0f;
CGFloat const WPLegacyEPVCStandardOffset = 15.0;
CGFloat const WPLegacyEPVCTextViewOffset = 10.0;
CGFloat const WPLegacyEPVCTextViewBottomPadding = 50.0f;
CGFloat const WPLegacyEPVCTextViewTopPadding = 7.0f;

@interface WPLegacyEditorViewController ()<UITextFieldDelegate, UITextViewDelegate, WPLegacyKeyboardToolbarDelegate>
@property (nonatomic) CGPoint scrollOffsetRestorePoint;
@property (nonatomic, strong) UIButton *optionsButton;
@property (nonatomic, strong) UILabel *tapToStartWritingLabel;
@property (nonatomic, strong) UITextField *titleTextField;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIView *optionsSeparatorView;
@property (nonatomic, strong) UIView *optionsView;
@property (nonatomic, strong) UIView *separatorView;
@property (nonatomic, strong) WPLegacyKeyboardToolbarBase *editorToolbar;
@property (nonatomic, strong) WPLegacyKeyboardToolbarDone *titleToolbar;
@end

@implementation WPLegacyEditorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // For the iPhone, let's let the overscroll background color be white to match the editor.
    if (IS_IPAD) {
        self.view.backgroundColor = [WPStyleGuide itsEverywhereGrey];
    }
    self.navigationController.navigationBar.translucent = NO;
    self.modalPresentationCapturesStatusBarAppearance = YES;
    [self setupToolbar];
    [self setupTextView];
    [self setupOptionsView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // When restoring state, the navigationController is nil when the view loads,
    // so configure its appearance here instead.
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbarHidden = NO;
    UIToolbar *toolbar = self.navigationController.toolbar;
    toolbar.barTintColor = [WPStyleGuide littleEddieGrey];
    toolbar.translucent = NO;
    toolbar.barStyle = UIBarStyleDefault;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    if(self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
    
    if (self.navigationController.toolbarHidden) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    
    for (UIView *view in self.navigationController.toolbar.subviews) {
        [view setExclusiveTouch:YES];
    }
    
    [self.textView setContentOffset:CGPointMake(0, 0)];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Refresh the UI when the view appears or the options
    // button won't be visible when restoring state.
    [self refreshUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [self.navigationController setToolbarHidden:YES animated:animated];
	[self stopEditing];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Getters and Setters

- (NSString*)titleText
{
    return self.titleTextField.text;
}

- (void) setTitleText:(NSString*)titleText
{
    [self.titleTextField setText:titleText];
    [self refreshUI];
}

- (NSString*)bodyText
{
    return self.textView.text;
}

- (void) setBodyText:(NSString*)bodyText
{
    [self.textView setText:bodyText];
    [self refreshUI];
}

#pragma mark - View Setup

- (void)setupToolbar
{
    if ([self.toolbarItems count] > 0) {
        return;
    }
    
    UIBarButtonItem *previewButton = [[UIBarButtonItem alloc] initWithImage:[self imageNamed:@"icon-posts-editor-preview"]
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(didTouchPreview)];
    UIBarButtonItem *photoButton = [[UIBarButtonItem alloc] initWithImage:[self imageNamed:@"icon-posts-editor-media"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(didTouchMediaOptions)];
    
    previewButton.tintColor = [WPStyleGuide readGrey];
    photoButton.tintColor = [WPStyleGuide readGrey];

    previewButton.accessibilityLabel = NSLocalizedString(@"Preview post", nil);
    photoButton.accessibilityLabel = NSLocalizedString(@"Add media", nil);
    
    UIBarButtonItem *leftFixedSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                     target:nil
                                                                                     action:nil];
    UIBarButtonItem *rightFixedSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                      target:nil
                                                                                      action:nil];
    UIBarButtonItem *centerFlexSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                      target:nil
                                                                                      action:nil];
    
    leftFixedSpacer.width = -2.0f;
    rightFixedSpacer.width = -5.0f;
    
    self.toolbarItems = @[leftFixedSpacer, previewButton, centerFlexSpacer, photoButton, rightFixedSpacer];
}

- (void)setupTextView
{
    CGFloat x = 0.0f;
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    CGFloat width = viewWidth;
    UIViewAutoresizing mask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (IS_IPAD) {
        width = WPTableViewFixedWidth;
        x = ceilf((viewWidth - width) / 2.0f);
        mask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
    }
    CGRect frame = CGRectMake(x, 0.0f, width, CGRectGetHeight(self.view.frame) - WPLegacyEPVCOptionsHeight);

    // Height should never be smaller than what is required to display its text.
    if (!self.textView) {
        self.textView = [[UITextView alloc] initWithFrame:frame];
        self.textView.autoresizingMask = mask;
        self.textView.delegate = self;
        self.textView.typingAttributes = [WPStyleGuide regularTextAttributes];
        self.textView.font = [WPStyleGuide regularTextFont];
        self.textView.textColor = [WPStyleGuide darkAsNightGrey];
        self.textView.accessibilityLabel = NSLocalizedString(@"Content", @"Post content");
    }
    [self.view addSubview:self.textView];
    
    // Formatting bar for the textView's inputAccessoryView.
    if (self.editorToolbar == nil) {
        frame = CGRectMake(0.0f, 0.0f, viewWidth, WPKT_HEIGHT_PORTRAIT);
        self.editorToolbar = [[WPLegacyKeyboardToolbarBase alloc] initWithFrame:frame];
        self.editorToolbar.backgroundColor = [WPStyleGuide keyboardColor];
        self.editorToolbar.delegate = self;
        self.textView.inputAccessoryView = self.editorToolbar;
    }
    
    // Title TextField.
    if (!self.titleTextField) {
        CGFloat textWidth = CGRectGetWidth(self.textView.frame) - (2 * WPLegacyEPVCStandardOffset);
        frame = CGRectMake(WPLegacyEPVCStandardOffset, 0.0, textWidth, WPLegacyEPVCTextfieldHeight);
        self.titleTextField = [[UITextField alloc] initWithFrame:frame];
        self.titleTextField.delegate = self;
        self.titleTextField.font = [WPStyleGuide postTitleFont];
        self.titleTextField.textColor = [WPStyleGuide darkAsNightGrey];
        self.titleTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.titleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:(NSLocalizedString(@"Enter title here", @"Label for the title of the post field. Should be the same as WP core.")) attributes:(@{NSForegroundColorAttributeName: [WPStyleGuide textFieldPlaceholderGrey]})];
        self.titleTextField.accessibilityLabel = NSLocalizedString(@"Title", @"Post title");
        self.titleTextField.returnKeyType = UIReturnKeyNext;
    }
    [self.textView addSubview:self.titleTextField];
    
    // InputAccessoryView for title textField.
    if (!self.titleToolbar) {
        frame = CGRectMake(0.0f, 0.0f, viewWidth, WPKT_HEIGHT_PORTRAIT);
        self.titleToolbar = [[WPLegacyKeyboardToolbarDone alloc] initWithFrame:frame];
        self.titleToolbar.backgroundColor = [WPStyleGuide keyboardColor];
        self.titleToolbar.delegate = self;
        self.titleTextField.inputAccessoryView = self.titleToolbar;
    }
    
    // One pixel separator bewteen title and content text fields.
    if (!self.separatorView) {
        CGFloat y = CGRectGetMaxY(self.titleTextField.frame);
        CGFloat separatorWidth = width - WPLegacyEPVCStandardOffset;
        frame = CGRectMake(WPLegacyEPVCStandardOffset, y, separatorWidth, 1.0);
        self.separatorView = [[UIView alloc] initWithFrame:frame];
        self.separatorView.backgroundColor = [WPStyleGuide readGrey];
        self.separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self.textView addSubview:self.separatorView];
    
    // Update the textView's textContainerInsets so text does not overlap content.
    CGFloat left = WPLegacyEPVCTextViewOffset;
    CGFloat right = WPLegacyEPVCTextViewOffset;
    CGFloat top = CGRectGetMaxY(self.separatorView.frame) + WPLegacyEPVCTextViewTopPadding;
    CGFloat bottom = WPLegacyEPVCTextViewBottomPadding;
    self.textView.textContainerInset = UIEdgeInsetsMake(top, left, bottom, right);

    if (!self.tapToStartWritingLabel) {
        frame = CGRectZero;
        frame.origin.x = WPLegacyEPVCStandardOffset;
        frame.origin.y = self.textView.textContainerInset.top;
        frame.size.width = width - (WPLegacyEPVCStandardOffset * 2);
        frame.size.height = 26.0f;
        self.tapToStartWritingLabel = [[UILabel alloc] initWithFrame:frame];
        self.tapToStartWritingLabel.text = NSLocalizedString(@"Tap here to begin writing", @"Placeholder for the main body text. Should hint at tapping to enter text (not specifying body text).");
        self.tapToStartWritingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.tapToStartWritingLabel.font = [WPStyleGuide regularTextFont];
        self.tapToStartWritingLabel.textColor = [WPStyleGuide textFieldPlaceholderGrey];
        self.tapToStartWritingLabel.isAccessibilityElement = NO;
    }
    [self.textView addSubview:self.tapToStartWritingLabel];
}

- (void)setupOptionsView
{
    CGFloat width = CGRectGetWidth(self.textView.frame);
    CGFloat x = CGRectGetMinX(self.textView.frame);
    CGFloat y = CGRectGetMaxY(self.textView.frame);
    
    CGRect frame;
    if (!self.optionsView) {
        frame = CGRectMake(x, y, width, WPLegacyEPVCOptionsHeight);
        self.optionsView = [[UIView alloc] initWithFrame:frame];
        self.optionsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        if (IS_IPAD) {
            self.optionsView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        }
        self.optionsView.backgroundColor = [UIColor whiteColor];
    }
    [self.view addSubview:self.optionsView];
    
    // One pixel separator bewteen content and table view cells.
    if (!self.optionsSeparatorView) {
        CGFloat separatorWidth = width - WPLegacyEPVCStandardOffset;
        frame = CGRectMake(WPLegacyEPVCStandardOffset, 0.0f, separatorWidth, 1.0f);
        self.optionsSeparatorView = [[UIView alloc] initWithFrame:frame];
        self.optionsSeparatorView.backgroundColor = [WPStyleGuide readGrey];
        self.optionsSeparatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self.optionsView addSubview:self.optionsSeparatorView];
    
    if (!self.optionsButton) {
        NSString *optionsTitle = NSLocalizedString(@"Options", @"Title of the Post Settings tableview cell in the Post Editor. Tapping shows settings and options related to the post being edited.");
        frame = CGRectMake(0.0f, 1.0f, width, WPLegacyEPVCOptionsHeight - 1.0f);
        self.optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.optionsButton.frame = frame;
        self.optionsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.optionsButton addTarget:self action:@selector(didTouchSettings)
                     forControlEvents:UIControlEventTouchUpInside];
        [self.optionsButton setBackgroundImage:[UIImage imageWithColor:[WPStyleGuide readGrey]]
                                      forState:UIControlStateHighlighted];
        self.optionsButton.accessibilityIdentifier = @"Options";
        // Rather than using a UIImageView to fake a disclosure icon, just use a cell and future proof the UI.
        WPTableViewCell *cell = [[WPTableViewCell alloc] initWithFrame:self.optionsButton.bounds];
        // The cell uses its default frame and ignores what was passed during init, so set it again.
        cell.frame = self.optionsButton.bounds;
        cell.backgroundColor = [UIColor clearColor];
        cell.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        cell.textLabel.text = optionsTitle;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.userInteractionEnabled = NO;
        [WPStyleGuide configureTableViewCell:cell];
        
        [self.optionsButton addSubview:cell];
    }
    [self.optionsView addSubview:self.optionsButton];
}

- (void)positionTextView:(NSNotification *)notification
{
    NSDictionary *keyboardInfo = [notification userInfo];
    CGRect originalKeyboardFrame = [[keyboardInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [self.view convertRect:[self.view.window convertRect:originalKeyboardFrame fromWindow:nil]
                                         fromView:nil];
    CGRect frame = self.textView.frame;
    
    if (self.isShowingKeyboard) {
        frame.size.height = CGRectGetMinY(keyboardFrame) - CGRectGetMinY(frame);
    } else {
        frame.size.height = CGRectGetHeight(self.view.frame) - WPLegacyEPVCOptionsHeight;
    }
    self.textView.frame = frame;
}

#pragma mark - Actions

- (void)didTouchSettings
{
    if ([self.delegate respondsToSelector: @selector(editorDidPressSettings:)]) {
        [self.delegate editorDidPressSettings:self];
    }
}

- (void)didTouchPreview
{
    if ([self.delegate respondsToSelector: @selector(editorDidPressPreview:)]) {
        [self.delegate editorDidPressPreview:self];
    }
}

- (void)didTouchMediaOptions
{
    if ([self.delegate respondsToSelector: @selector(editorDidPressMedia:)]) {
        [self.delegate editorDidPressMedia:self];
    }
}

#pragma mark - Editor and Misc Methods

- (void)stopEditing
{
    // With the titleTextField as a subview of textField, we need to resign and
    // end editing to prevent the textField from becomeing first responder.
    if ([self.titleTextField isFirstResponder]) {
        [self.titleTextField resignFirstResponder];
    }
    [self.view endEditing:YES];
}

- (void)refreshUI
{
    if(self.titleText != nil || self.titleText.length != 0) {
        self.title = self.titleText;
    }
    if(!self.bodyText || self.bodyText.length == 0) {
        self.tapToStartWritingLabel.hidden = NO;
        self.textView.text = @"";
    } else {
        self.tapToStartWritingLabel.hidden = YES;
    }
}

- (void)showLinkView
{
    __weak __typeof(self)weakSelf = self;
    NSRange range = self.textView.selectedRange;
    [self.textView resignFirstResponder];
    
    NSString *infoText = nil;
    if (range.length > 0) {
        infoText = [self.textView.text substringWithRange:range];
    }
    self.scrollOffsetRestorePoint = self.textView.contentOffset;
    
    NSString *alertViewTitle = NSLocalizedString(@"Make a Link", @"Title of the Link Helper popup to aid in creating a Link in the Post Editor.");
    NSCharacterSet *charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    alertViewTitle = [alertViewTitle stringByTrimmingCharactersInSet:charSet];
    
    NSString *insertButtonTitle = NSLocalizedString(@"Insert", @"Insert content (link, media) button");
    NSString *cancelButtonTitle = NSLocalizedString(@"Cancel", @"Cancel button");
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:insertButtonTitle
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Link URL", @"Popup to aid in creating a Link in the Post Editor, URL field (where you can type or paste a URL that the text should link.");
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.keyboardAppearance = UIKeyboardAppearanceAlert;
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        
        [textField addTarget:weakSelf
                      action:@selector(alertTextFieldDidChange:)
            forControlEvents:UIControlEventEditingChanged];
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = NO;
        textField.placeholder = NSLocalizedString(@"Text to be linked", @"Popup to aid in creating a Link in the Post Editor.");
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.keyboardAppearance = UIKeyboardAppearanceAlert;
        textField.keyboardType = UIKeyboardTypeDefault;
        
        if (infoText) {
            textField.text = infoText;
        }
    }];
    
    UIAlertAction* insertAction = [UIAlertAction actionWithTitle:insertButtonTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             
                                                             // Insert link
                                                             UITextField *urlField = alertController.textFields.firstObject;
                                                             UITextField *infoText = alertController.textFields.lastObject;
                                                             
                                                             if ((urlField.text == nil) || ([urlField.text isEqualToString:@""])) {
                                                                 return;
                                                             }
                                                             
                                                             if ((infoText.text == nil) || ([infoText.text isEqualToString:@""])) {
                                                                 infoText.text = urlField.text;
                                                             }
                                                             
                                                             [weakSelf.textView becomeFirstResponder];
                                                             weakSelf.textView.selectedRange = range;
                                                             
                                                             NSString *urlString = [weakSelf validateNewLinkInfo:[urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                                                             NSString *aTagText = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlString, infoText.text];
                                                             
                                                             [weakSelf.textView insertText:aTagText];
                                                             [weakSelf textViewDidChange:weakSelf.textView];
                                                         }];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {}];
    
    [alertController addAction:insertAction];
    [alertController addAction:cancelAction];
    
    // Disabled until url is entered into field
    insertAction.enabled = NO;
    [self presentViewController:alertController
                       animated:YES
                     completion:nil];
}

- (void)alertTextFieldDidChange:(UITextField *)sender
{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController)
    {
        UITextField *urlField = alertController.textFields.firstObject;
        UIAlertAction *insertAction = alertController.actions.firstObject;
        insertAction.enabled = urlField.text.length > 0;
    }
}

// Appends http:// if protocol part is not there as part of urlText.
- (NSString *)validateNewLinkInfo:(NSString *)urlText
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[\\w]+:" options:0 error:&error];
    
    if ([regex numberOfMatchesInString:urlText options:0 range:NSMakeRange(0, [urlText length])] > 0) {
        return urlText;
    } else if([urlText hasPrefix:@"#"]) {
        // link to named anchor
        return urlText;
    } else {
        return [NSString stringWithFormat:@"http://%@", urlText];
    }
}

- (UIImage *)imageNamed:(NSString *)imageName {
    NSBundle* editorBundle = [NSBundle bundleForClass:[self class]];
    return [UIImage imageNamed:imageName inBundle:editorBundle compatibleWithTraitCollection:nil];
}

#pragma mark - Formatting

- (void)wrapSelectionWithTag:(NSString *)tag
{
    NSRange range = self.textView.selectedRange;
    NSString *selection = [self.textView.text substringWithRange:range];
    NSString *prefix, *suffix;
    if ([tag isEqualToString:@"more"]) {
        prefix = @"<!--more-->";
        suffix = @"\n";
    } else if ([tag isEqualToString:@"blockquote"]) {
        prefix = [NSString stringWithFormat:@"\n<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    } else {
        prefix = [NSString stringWithFormat:@"<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>", tag];
    }
    
    NSString *replacement = [NSString stringWithFormat:@"%@%@%@",prefix,selection,suffix];
    [self.textView insertText:replacement];
    [self textViewDidChange:self.textView];
}

#pragma mark - WPKeyboardToolbar Delegate

- (void)keyboardToolbarButtonItemPressed:(WPLegacyKeyboardToolbarButtonItem *)buttonItem
{
    if ([buttonItem.actionTag isEqualToString:@"strong"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedBold];
    } else if ([buttonItem.actionTag isEqualToString:@"em"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedItalic];
    } else if ([buttonItem.actionTag isEqualToString:@"u"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedUnderline];
    } else if ([buttonItem.actionTag isEqualToString:@"del"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedStrikethrough];
    } else if ([buttonItem.actionTag isEqualToString:@"link"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedLink];
    } else if ([buttonItem.actionTag isEqualToString:@"blockquote"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedBlockquote];
    } else if ([buttonItem.actionTag isEqualToString:@"more"]) {
        [WPAnalytics track:WPAnalyticsStatEditorTappedMore];
    }
         
    if ([buttonItem.actionTag isEqualToString:@"link"]) {
        [self showLinkView];
    } else if ([buttonItem.actionTag isEqualToString:@"done"]) {
        [self stopEditing];
    } else {
        [self wrapSelectionWithTag:buttonItem.actionTag];
        [self.textView.undoManager setActionName:buttonItem.actionName];
    }
}

#pragma mark - TextView Delegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if ([self.delegate respondsToSelector: @selector(editorShouldBeginEditing:)]) {
        return [self.delegate editorShouldBeginEditing:self];
    }
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    self.tapToStartWritingLabel.hidden = YES;
}

- (void)textViewDidChange:(UITextView *)aTextView
{
    if ([self.delegate respondsToSelector: @selector(editorTextDidChange:)]) {
        [self.delegate editorTextDidChange:self];
    }
}

- (void)textViewDidEndEditing:(UITextView *)aTextView
{
    if ([self.textView.text isEqualToString:@""]) {
        self.tapToStartWritingLabel.hidden = NO;
    }
}

#pragma mark - TextField delegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ([self.delegate respondsToSelector: @selector(editorShouldBeginEditing:)]) {
        return [self.delegate editorShouldBeginEditing:self];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.titleTextField) {
        [self setTitle:[textField.text stringByReplacingCharactersInRange:range withString:string]];
        if ([self.delegate respondsToSelector: @selector(editorTitleDidChange:)]) {
            [self.delegate editorTitleDidChange:self];
        }
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.textView becomeFirstResponder];
    return NO;
}

#pragma mark - Positioning & Rotation

- (BOOL)shouldHideToolbarsWhileTyping
{
    /*
     Never hide for the iPad.
     Always hide on the iPhone except for portrait + external keyboard
     */
    if (IS_IPAD) {
        return NO;
    }
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    if (!isLandscape && self.isExternalKeyboard) {
        return NO;
    }
    
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect frame = self.editorToolbar.frame;
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        if (IS_IPAD) {
            frame.size.height = WPKT_HEIGHT_IPAD_LANDSCAPE;
        } else {
            frame.size.height = WPKT_HEIGHT_IPHONE_LANDSCAPE;
        }
        
    } else {
        if (IS_IPAD) {
            frame.size.height = WPKT_HEIGHT_IPAD_PORTRAIT;
        } else {
            frame.size.height = WPKT_HEIGHT_IPHONE_PORTRAIT;
        }
    }
    self.editorToolbar.frame = frame;
    self.titleToolbar.frame = frame; // Frames match, no need to re-calc.
}

#pragma mark - Status bar management

- (BOOL)prefersStatusBarHidden
{
    return self.isShowingKeyboard;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationSlide;
}

#pragma mark - Keyboard management

- (void)keyboardWillShow:(NSNotification *)notification
{
	self.isShowingKeyboard = YES;
    
    if ([self shouldHideToolbarsWhileTyping]) {
        [self setNeedsStatusBarAppearanceUpdate];
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES animated:NO];
    }
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    if ([self.textView isFirstResponder]) {
        if (!CGPointEqualToPoint(CGPointZero, self.scrollOffsetRestorePoint)) {
            self.textView.contentOffset = self.scrollOffsetRestorePoint;
            self.scrollOffsetRestorePoint = CGPointZero;
        }
    }
    [self positionTextView:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	self.isShowingKeyboard = NO;
    [self setNeedsStatusBarAppearanceUpdate];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:NO];
    [self positionTextView:notification];
}

@end
