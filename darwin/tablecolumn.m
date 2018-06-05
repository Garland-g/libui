// 3 june 2018
#import "uipriv_darwin.h"
#import "table.h"

// values from interface builder
#define textColumnLeading 2
#define textColumnTrailing 2
#define imageColumnLeading 3
#define imageTextColumnLeading 7
#define checkboxTextColumnLeading 0
// these aren't provided by IB; let's just choose one
#define checkboxColumnLeading imageColumnLeading
#define progressBarColumnLeading imageColumnLeading
#define progressBarColumnTrailing progressBarColumnLeading
#define buttonColumnLeading imageColumnLeading
#define buttonColumnTrailing buttonColumnLeading

@implementation uiprivTableCellView

- (void)uiprivUpdate:(NSInteger)row
{
	[self doesNotRecognizeSelector:_cmd];
}

@end

@implementation uiprivTableColumn

- (uiprivTableCellView *)uiprivMakeCellView
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;			// appease compiler
}

@end

static BOOL isCellEditable(uiTableModel *m, NSInteger row, int modelColumn)
{
	uiTableData *data;
	int value;

	switch (modelColumn) {
	case uiTableModelColumnNeverEditable:
		return NO;
	case uiTableModelColumnAlwaysEditable:
		return YES;
	}
	data = (*(m->mh->CellValue))(m->mh, m, row, modelColumn);
	value = uiTableDataInt(data);
	uiFreeTableData(data);
	return value != 0;
	// TODO free data
}

static uiTableTextColumnOptionalParams defaultTextColumnOptionalParams = {
	.ColorModelColumn = -1,
};

struct textColumnCreateParams {
	uiTable *t;
	uiTableModel *m;

	BOOL makeTextField;
	int textModelColumn;
	int textEditableColumn;
	uiTableTextColumnOptionalParams textParams;

	BOOL makeImage;
	int imageModelColumn;

	BOOL makeCheckbox;
	int checkboxModelColumn;
	int checkboxEditableColumn;
};

@interface uiprivTextImageCheckboxTableCellView : uiprivTableCellView {
	uiTable *t;
	uiTableModel *m;

	NSTextField *tf;
	int textModelColumn;
	int textEditableColumn;
	uiTableTextColumnOptionalParams textParams;

	NSImageView *iv;
	int imageModelColumn;

	NSButton *cb;
	int checkboxModelColumn;
	int checkboxEditableColumn;
}
- (id)initWithFrame:(NSRect)r params:(struct textColumnCreateParams *)p;
- (IBAction)uiprivOnTextFieldAction:(id)sender;
- (IBAction)uiprivOnCheckboxAction:(id)sender;
@end

@implementation uiprivTextImageCheckboxTableCellView

- (id)initWithFrame:(NSRect)r params:(struct textColumnCreateParams *)p
{
	self = [super initWithFrame:r];
	if (self) {
		NSMutableArray *constraints;

		self->t = p->t;
		self->m = p->m;
		constraints = [NSMutableArray new];

		self->tf = nil;
		if (p->makeTextField) {
			self->textModelColumn = p->textModelColumn;
			self->textEditableColumn = p->textEditableColumn;
			self->textParams = p->textParams;

			self->tf = uiprivNewLabel(@"");
			// TODO set wrap and ellipsize modes?
			[self->tf setTarget:self];
			[self->tf setAction:@selector(uiprivOnTextFieldAction:)];
			[self->tf setTranslatesAutoresizingMaskIntoConstraints:NO];
			[self addSubview:self->tf];

			// TODO for all three controls: set hugging and compression resistance properly
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeLeading,
				NSLayoutRelationEqual,
				self->tf, NSLayoutAttributeLeading,
				1, -textColumnLeading,
				@"uiTable cell text leading constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeTop,
				NSLayoutRelationEqual,
				self->tf, NSLayoutAttributeTop,
				1, 0,
				@"uiTable cell text top constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeTrailing,
				NSLayoutRelationEqual,
				self->tf, NSLayoutAttributeTrailing,
				1, textColumnTrailing,
				@"uiTable cell text trailing constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeBottom,
				NSLayoutRelationEqual,
				self->tf, NSLayoutAttributeBottom,
				1, 0,
				@"uiTable cell text bottom constraint")];
		}

		self->iv = nil;
		// TODO rename to makeImageView
		if (p->makeImage) {
			self->imageModelColumn = p->imageModelColumn;

			self->iv = [[NSImageView alloc] initWithFrame:NSZeroRect];
			[self->iv setImageFrameStyle:NSImageFrameNone];
			[self->iv setImageAlignment:NSImageAlignCenter];
			[self->iv setImageScaling:NSImageScaleProportionallyDown];
			[self->iv setAnimates:NO];
			[self->iv setEditable:NO];
			[self->iv setTranslatesAutoresizingMaskIntoConstraints:NO];
			[self addSubview:self->iv];

			[constraints addObject:uiprivMkConstraint(self->iv, NSLayoutAttributeWidth,
				NSLayoutRelationEqual,
				self->iv, NSLayoutAttributeHeight,
				1, 0,
				@"uiTable image squareness constraint")];
			if (self->tf != nil) {
				[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeLeading,
					NSLayoutRelationEqual,
					self->iv, NSLayoutAttributeLeading,
					1, -imageColumnLeading,
					@"uiTable cell image leading constraint")];
				[constraints replaceObjectAtIndex:0
					withObject:uiprivMkConstraint(self->iv, NSLayoutAttributeTrailing,
						NSLayoutRelationEqual,
						self->tf, NSLayoutAttributeLeading,
						1, -imageTextColumnLeading,
						@"uiTable cell image-text spacing constraint")];
			} else
				[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeCenterX,
					NSLayoutRelationEqual,
					self->iv, NSLayoutAttributeCenterX,
					1, 0,
					@"uiTable cell image centering constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeTop,
				NSLayoutRelationEqual,
				self->iv, NSLayoutAttributeTop,
				1, 0,
				@"uiTable cell image top constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeBottom,
				NSLayoutRelationEqual,
				self->iv, NSLayoutAttributeBottom,
				1, 0,
				@"uiTable cell image bottom constraint")];
		}

		self->cb = nil;
		if (p->makeCheckbox) {
			self->checkboxModelColumn = p->checkboxModelColumn;
			self->checkboxEditableColumn = p->checkboxEditableColumn;

			self->cb = [[NSButton alloc] initWithFrame:NSZeroRect];
			[self->cb setTitle:@""];
			[self->cb setButtonType:NSSwitchButton];
			// doesn't seem to have an associated bezel style
			[self->cb setBordered:NO];
			[self->cb setTransparent:NO];
			uiDarwinSetControlFont(self->cb, NSRegularControlSize);
			[self->cb setTranslatesAutoresizingMaskIntoConstraints:NO];
			[self addSubview:self->cb];

			if (self->tf != nil) {
				[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeLeading,
					NSLayoutRelationEqual,
					self->cb, NSLayoutAttributeLeading,
					1, -imageColumnLeading,
					@"uiTable cell checkbox leading constraint")];
				[constraints replaceObjectAtIndex:0
					withObject:uiprivMkConstraint(self->cb, NSLayoutAttributeTrailing,
						NSLayoutRelationEqual,
						self->tf, NSLayoutAttributeLeading,
						1, -imageTextColumnLeading,
						@"uiTable cell checkbox-text spacing constraint")];
			} else
				[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeCenterX,
					NSLayoutRelationEqual,
					self->cb, NSLayoutAttributeCenterX,
					1, 0,
					@"uiTable cell checkbox centering constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeTop,
				NSLayoutRelationEqual,
				self->cb, NSLayoutAttributeTop,
				1, 0,
				@"uiTable cell checkbox top constraint")];
			[constraints addObject:uiprivMkConstraint(self, NSLayoutAttributeBottom,
				NSLayoutRelationEqual,
				self->cb, NSLayoutAttributeBottom,
				1, 0,
				@"uiTable cell checkbox bottom constraint")];
		}

		[self addConstraints:constraints];

		// take advantage of NSTableCellView-provided accessibility features
		if (self->tf != nil)
			[self setTextField:self->tf];
		if (self->iv != nil)
			[self setImageView:self->iv];
	}
	return self;
}

- (void)dealloc
{
	if (self->cb != nil) {
		[self->cb release];
		self->cb = nil;
	}
	if (self->iv != nil) {
		[self->iv release];
		self->iv = nil;
	}
	if (self->tf != nil) {
		[self->tf release];
		self->tf = nil;
	}
	[super dealloc];
}

- (void)uiprivUpdate:(NSInteger)row
{
	uiTableData *data;

	if (self->tf != nil) {
		NSString *str;
		NSColor *color;

		data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->textModelColumn);
		str = uiprivToNSString(uiTableDataString(data));
		uiFreeTableData(data);
		[self->tf setStringValue:str];

		[self->tf setEditable:isCellEditable(self->m, row, self->textEditableColumn)];

		color = nil;
		if (self->textParams.ColorModelColumn != -1) {
			double r, g, b, a;

			data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->textParams.ColorModelColumn);
			// TODO document this is allowed
			if (data != NULL) {
				uiTableDataColor(data, &r, &g, &b, &a);
				uiFreeTableData(data);
				color = [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
			}
		}
		if (color == nil)
			color = [NSColor controlTextColor];
		[self->tf setTextColor:color];
		// we don't own color in ether case; don't release
	}
	if (self->iv != nil) {
		uiImage *img;

		data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->imageModelColumn);
		img = uiTableDataImage(data);
		uiFreeTableData(data);
		[self->iv setImage:uiprivImageNSImage(img)];
	}
	if (self->cb != nil) {
		data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->imageModelColumn);
		if (uiTableDataInt(data) != 0)
			[self->cb setState:NSOnState];
		else
			[self->cb setState:NSOffState];
		uiFreeTableData(data);

		[self->cb setEnabled:isCellEditable(self->m, row, self->checkboxEditableColumn)];
	}
}

- (IBAction)uiprivOnTextFieldAction:(id)sender
{
	NSInteger row;
	uiTableData *data;

	row = [self->t->tv rowForView:self->tf];
	data = uiNewTableDataString([[self->tf stringValue] UTF8String]);
	(*(self->m->mh->SetCellValue))(self->m->mh, self->m,
		row, self->textModelColumn, data);
	uiFreeTableData(data);
	// always refresh the value in case the model rejected it
	[self uiprivUpdate:row];
}

- (IBAction)uiprivOnCheckboxAction:(id)sender
{
	NSInteger row;
	void *data;

	row = [self->t->tv rowForView:self->cb];
	data = uiNewTableDataInt([self->cb state] != NSOffState);
	(*(self->m->mh->SetCellValue))(self->m->mh, self->m,
		row, self->checkboxModelColumn, data);
	uiFreeTableData(data);
	// always refresh the value in case the model rejected it
	[self uiprivUpdate:row];
}

@end

@interface uiprivTextImageCheckboxTableColumn : uiprivTableColumn {
	struct textColumnCreateParams params;
}
- (id)initWithIdentifier:(NSString *)ident params:(struct textColumnCreateParams *)p;
@end

@implementation uiprivTextImageCheckboxTableColumn

- (id)initWithIdentifier:(NSString *)ident params:(struct textColumnCreateParams *)p
{
	self = [super initWithIdentifier:ident];
	if (self)
		self->params = *p;
	return self;
}

- (uiprivTableCellView *)uiprivMakeCellView
{
	uiprivTableCellView *cv;

	cv = [[uiprivTextImageCheckboxTableCellView alloc] initWithFrame:NSZeroRect params:&(self->params)];
	[cv setIdentifier:[self identifier]];
	return cv;
}

@end

@interface uiprivProgressBarTableCellView : uiprivTableCellView {
	uiTable *t;
	uiTableModel *m;
	NSProgressIndicator *p;
	int modelColumn;
}
- (id)initWithFrame:(NSRect)r table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc;
@end

@implementation uiprivProgressBarTableCellView

- (id)initWithFrame:(NSRect)r table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc
{
	self = [super initWithFrame:r];
	if (self) {
		self->t = table;
		self->m = model;
		self->modelColumn = mc;

		self->p = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
		[self->p setControlSize:NSRegularControlSize];
		[self->p setBezeled:YES];
		[self->p setStyle:NSProgressIndicatorBarStyle];
		[self->p setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self addSubview:self->p];

		// TODO set hugging and compression resistance properly
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeLeading,
			NSLayoutRelationEqual,
			self->p, NSLayoutAttributeLeading,
			1, -progressBarColumnLeading,
			@"uiTable cell progressbar leading constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeTop,
			NSLayoutRelationEqual,
			self->p, NSLayoutAttributeTop,
			1, 0,
			@"uiTable cell progressbar top constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeTrailing,
			NSLayoutRelationEqual,
			self->p, NSLayoutAttributeTrailing,
			1, progressBarColumnTrailing,
			@"uiTable cell progressbar trailing constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeBottom,
			NSLayoutRelationEqual,
			self->p, NSLayoutAttributeBottom,
			1, 0,
			@"uiTable cell progressbar bottom constraint")];
	}
	return self;
}

- (void)dealloc
{
	[self->p release];
	self->p = nil;
	[super dealloc];
}

- (void)uiprivUpdate:(NSInteger)row
{
	uiTableData *data;
	int value;

	data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->modelColumn);
	value = uiTableDataInt(data);
	uiFreeTableData(data);
	if (value == -1) {
		[self->p setIndeterminate:YES];
		[self->p startAnimation:self->p];
	} else if (value == 100) {
		[self->p setIndeterminate:NO];
		[self->p setMaxValue:101];
		[self->p setDoubleValue:101];
		[self->p setDoubleValue:100];
		[self->p setMaxValue:100];
	} else {
		[self->p setIndeterminate:NO];
		[self->p setDoubleValue:(value + 1)];
		[self->p setDoubleValue:value];
	}
}

@end

@interface uiprivProgressBarTableColumn : uiprivTableColumn {
	uiTable *t;
	// TODO remove the need for this given t (or make t not require m, one of the two)
	uiTableModel *m;
	int modelColumn;
}
- (id)initWithIdentifier:(NSString *)ident table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc;
@end

@implementation uiprivProgressBarTableColumn

- (id)initWithIdentifier:(NSString *)ident table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc
{
	self = [super initWithIdentifier:ident];
	if (self) {
		self->t = table;
		self->m = model;
		self->modelColumn = mc;
	}
	return self;
}

- (uiprivTableCellView *)uiprivMakeCellView
{
	uiprivTableCellView *cv;

	cv = [[uiprivProgressBarTableCellView alloc] initWithFrame:NSZeroRect table:self->t model:self->m modelColumn:self->modelColumn];
	[cv setIdentifier:[self identifier]];
	return cv;
}

@end

@interface uiprivButtonTableCellView : uiprivTableCellView {
	uiTable *t;
	uiTableModel *m;
	NSButton *b;
	int modelColumn;
	int editableColumn;
}
- (id)initWithFrame:(NSRect)r table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc editableColumn:(int)ec;
- (IBAction)uiprivOnClicked:(id)sender;
@end

@implementation uiprivButtonTableCellView

- (id)initWithFrame:(NSRect)r table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc editableColumn:(int)ec
{
	self = [super initWithFrame:r];
	if (self) {
		self->t = table;
		self->m = model;
		self->modelColumn = mc;
		self->editableColumn = ec;

		self->b = [[NSButton alloc] initWithFrame:NSZeroRect];
		[self->b setButtonType:NSMomentaryPushInButton];
		[self->b setBordered:YES];
		[self->b setBezelStyle:NSRoundRectBezelStyle];
		uiDarwinSetControlFont(self->b, NSRegularControlSize);
		[self->b setTarget:self];
		[self->b setAction:@selector(uiprivOnClicked:)];
		[self->b setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self addSubview:self->b];

		// TODO set hugging and compression resistance properly
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeLeading,
			NSLayoutRelationEqual,
			self->b, NSLayoutAttributeLeading,
			1, -buttonColumnLeading,
			@"uiTable cell button leading constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeTop,
			NSLayoutRelationEqual,
			self->b, NSLayoutAttributeTop,
			1, 0,
			@"uiTable cell button top constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeTrailing,
			NSLayoutRelationEqual,
			self->b, NSLayoutAttributeTrailing,
			1, buttonColumnTrailing,
			@"uiTable cell button trailing constraint")];
		[self addConstraint:uiprivMkConstraint(self, NSLayoutAttributeBottom,
			NSLayoutRelationEqual,
			self->b, NSLayoutAttributeBottom,
			1, 0,
			@"uiTable cell button bottom constraint")];
	}
	return self;
}

- (void)dealloc
{
	[self->b release];
	self->b = nil;
	[super dealloc];
}

- (void)uiprivUpdate:(NSInteger)row
{
	uiTableData *data;
	NSString *str;

	data = (*(self->m->mh->CellValue))(self->m->mh, self->m, row, self->modelColumn);
	str = uiprivToNSString(uiTableDataString(data));
	uiFreeTableData(data);
	[self->b setTitle:str];

	[self->b setEnabled:isCellEditable(self->m, row, self->editableColumn)];
}

- (IBAction)uiprivOnClicked:(id)sender
{
	// TODO
}

@end

@interface uiprivButtonTableColumn : uiprivTableColumn {
	uiTable *t;
	uiTableModel *m;
	int modelColumn;
	int editableColumn;
}
- (id)initWithIdentifier:(NSString *)ident table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc editableColumn:(int)ec;
@end

@implementation uiprivButtonTableColumn

- (id)initWithIdentifier:(NSString *)ident table:(uiTable *)table model:(uiTableModel *)model modelColumn:(int)mc editableColumn:(int)ec
{
	self = [super initWithIdentifier:ident];
	if (self) {
		self->t = table;
		self->m = model;
		self->modelColumn = mc;
		self->editableColumn = ec;
	}
	return self;
}

- (uiprivTableCellView *)uiprivMakeCellView
{
	uiprivTableCellView *cv;

	cv = [[uiprivButtonTableCellView alloc] initWithFrame:NSZeroRect table:self->t model:self->m modelColumn:self->modelColumn editableColumn:self->editableColumn];
	[cv setIdentifier:[self identifier]];
	return cv;
}

@end

void uiTableAppendTextColumn(uiTable *t, const char *name, int textModelColumn, int textEditableModelColumn, uiTableTextColumnOptionalParams *params)
{
	struct textColumnCreateParams p;
	uiprivTableColumn *col;
	NSString *str;

	memset(&p, 0, sizeof (struct textColumnCreateParams));
	p.t = t;
	p.m = t->m;

	p.makeTextField = YES;
	p.textModelColumn = textModelColumn;
	p.textEditableColumn = textEditableModelColumn;
	if (params == NULL)
		params = &defaultTextColumnOptionalParams;
	p.textParams = *params;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivTextImageCheckboxTableColumn alloc] initWithIdentifier:str params:&p];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendImageColumn(uiTable *t, const char *name, int imageModelColumn)
{
	struct textColumnCreateParams p;
	uiprivTableColumn *col;
	NSString *str;

	memset(&p, 0, sizeof (struct textColumnCreateParams));
	p.t = t;
	p.m = t->m;

	p.makeImage = YES;
	p.imageModelColumn = imageModelColumn;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivTextImageCheckboxTableColumn alloc] initWithIdentifier:str params:&p];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendImageTextColumn(uiTable *t, const char *name, int imageModelColumn, int textModelColumn, int textEditableModelColumn, uiTableTextColumnOptionalParams *textParams)
{
	struct textColumnCreateParams p;
	uiprivTableColumn *col;
	NSString *str;

	memset(&p, 0, sizeof (struct textColumnCreateParams));
	p.t = t;
	p.m = t->m;

	p.makeTextField = YES;
	p.textModelColumn = textModelColumn;
	p.textEditableColumn = textEditableModelColumn;
	if (textParams == NULL)
		textParams = &defaultTextColumnOptionalParams;
	p.textParams = *textParams;

	p.makeImage = YES;
	p.imageModelColumn = imageModelColumn;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivTextImageCheckboxTableColumn alloc] initWithIdentifier:str params:&p];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendCheckboxColumn(uiTable *t, const char *name, int checkboxModelColumn, int checkboxEditableModelColumn)
{
	struct textColumnCreateParams p;
	uiprivTableColumn *col;
	NSString *str;

	memset(&p, 0, sizeof (struct textColumnCreateParams));
	p.t = t;
	p.m = t->m;

	p.makeCheckbox = YES;
	p.checkboxModelColumn = checkboxModelColumn;
	p.checkboxEditableColumn = checkboxEditableModelColumn;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivTextImageCheckboxTableColumn alloc] initWithIdentifier:str params:&p];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendCheckboxTextColumn(uiTable *t, const char *name, int checkboxModelColumn, int checkboxEditableModelColumn, int textModelColumn, int textEditableModelColumn, uiTableTextColumnOptionalParams *textParams)
{
	struct textColumnCreateParams p;
	uiprivTableColumn *col;
	NSString *str;

	memset(&p, 0, sizeof (struct textColumnCreateParams));
	p.t = t;
	p.m = t->m;

	p.makeTextField = YES;
	p.textModelColumn = textModelColumn;
	p.textEditableColumn = textEditableModelColumn;
	if (textParams == NULL)
		textParams = &defaultTextColumnOptionalParams;
	p.textParams = *textParams;

	p.makeCheckbox = YES;
	p.checkboxModelColumn = checkboxModelColumn;
	p.checkboxEditableColumn = checkboxEditableModelColumn;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivTextImageCheckboxTableColumn alloc] initWithIdentifier:str params:&p];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendProgressBarColumn(uiTable *t, const char *name, int progressModelColumn)
{
	uiprivTableColumn *col;
	NSString *str;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivProgressBarTableColumn alloc] initWithIdentifier:str table:t model:t->m modelColumn:progressModelColumn];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}

void uiTableAppendButtonColumn(uiTable *t, const char *name, int buttonTextModelColumn, int buttonClickableModelColumn)
{
	uiprivTableColumn *col;
	NSString *str;

	str = [NSString stringWithUTF8String:name];
	col = [[uiprivButtonTableColumn alloc] initWithIdentifier:str table:t model:t->m modelColumn:buttonTextModelColumn editableColumn:buttonClickableModelColumn];
	[col setTitle:str];
	[t->tv addTableColumn:col];
}