//
//  ViewController.m
//  JXPriorityQueueDemo-UI
//
//  Created by JiongXing on 2016/11/8.
//  Copyright © 2016年 JiongXing. All rights reserved.
//

#import "ViewController.h"
#import "LineView.h"
#import "JXPriorityQueue.h"

static const CGFloat kNodeSize = 34;

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray<UILabel *> *nodeArray;
@property (nonatomic, strong) NSMutableArray<LineView *> *lineArray;

@property (nonatomic, strong) NSArray *data;
@property (nonatomic, strong) JXPriorityQueue *queue;
@property (nonatomic, strong) dispatch_semaphore_t sema;
@property (nonatomic, assign) BOOL signal;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化资源
    self.nodeArray = [NSMutableArray array];
    self.lineArray = [NSMutableArray array];
    
    self.data = @[@40, @10, @60, @30, @70, @20, @50, @80, @90, @100];
    self.sema = dispatch_semaphore_create(0);
    
    self.queue = [JXPriorityQueue queueWithComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        NSInteger num1 = obj1.integerValue;
        NSInteger num2 = obj2.integerValue;
        if (num1 == num2) {
            return NSOrderedSame;
        }
        return num1 < num2 ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    __weak typeof(self) weakSelf = self;
    
    // 结点交换
    [self.queue setDidSwapCallBack:^(NSInteger indexA, NSInteger indexB) {
        // 暂停以等待信号
        dispatch_semaphore_wait(weakSelf.sema, DISPATCH_TIME_FOREVER);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 同步刷新UI，交换两结点
            UILabel *nodeA = weakSelf.nodeArray[indexA];
            UILabel *nodeB = weakSelf.nodeArray[indexB];
            nodeA.backgroundColor = [UIColor yellowColor];
            nodeB.backgroundColor = [UIColor yellowColor];
            [UIView animateWithDuration:0.4 animations:^{
                CGRect temp = nodeA.frame;
                nodeA.frame = nodeB.frame;
                nodeB.frame = temp;
            } completion:^(BOOL finished) {
                nodeA.backgroundColor = [UIColor whiteColor];
                nodeB.backgroundColor = [UIColor whiteColor];
                weakSelf.nodeArray[indexA] = nodeB;
                weakSelf.nodeArray[indexB] = nodeA;
            }];
        });
    }];
    
    // 定时发出信号，以允许继续交换
    [NSTimer scheduledTimerWithTimeInterval:0.6 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (self.signal) {
            dispatch_semaphore_signal(weakSelf.sema);
        }
    }];
}

- (void)refreshWithData:(NSArray<NSNumber *> *)data {
    [self.nodeArray enumerateObjectsUsingBlock:^(UILabel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    [self.lineArray enumerateObjectsUsingBlock:^(LineView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat nodeSpaceHeight = 60;
    for (NSInteger index = 1; index <= data.count; index ++) {
        // 从0开始
        NSInteger level = log2f(index);
        // 本层最多有多少个结点
        NSInteger count = powf(2, level);
        // 给本层的结点编号，从0开始
        NSInteger sequence = index % count;
        // 一个结点所属的空间宽度
        CGFloat nodeSpaceWidth = width / (2 * count);
        CGFloat centerX = (1 + sequence * 2) * nodeSpaceWidth;
        CGFloat centerY = (1 + level) * nodeSpaceHeight;
        
        // 画结点
        UILabel *node = [self nodeWithIndex:index - 1];
        node.text = [NSString stringWithFormat:@"%@", data[index - 1]];
        node.center = CGPointMake(centerX, centerY);
        node.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:node];
        
        // 画线
        if (index > 1) {
            UILabel *parentNode = [self nodeWithIndex:index / 2 - 1];
            LineView *line = [self lineWithIndex:index - 1];
            line.isRight = sequence % 2 == 1;
            CGFloat lineX = line.isRight ? parentNode.center.x : node.center.x;
            line.frame = CGRectMake(lineX,
                                    parentNode.center.y,
                                    ABS(node.center.x - parentNode.center.x),
                                    ABS(node.center.y - parentNode.center.y));
            [self.view insertSubview:line atIndex:0];
        }
    }
}

- (IBAction)onEnQueue:(UIButton *)sender {
    if (self.signal) {
        return;
    }
    
    if (self.queue.count < self.data.count) {
        id obj = self.data[self.queue.count];
        NSMutableArray *data = [[self.queue fetchData] mutableCopy];
        [data addObject:obj];
        [self refreshWithData:data];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.signal = YES;
            [self.queue enQueue:obj];
            self.signal = NO;
            [self.queue logDataWithMessage:@"enQueue"];
        });
    }
}

- (IBAction)onDeQueue:(UIButton *)sender {
    if (self.signal) {
        return;
    }
    
    if (self.queue.count == 0) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.signal = YES;
        [self.queue deQueue];
        
        // 出列完成，刷新UI去掉末尾结点
        dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            UILabel *lastNode = self.nodeArray[self.queue.count];
            [lastNode removeFromSuperview];
            LineView *lastLine = self.lineArray[self.queue.count];
            [lastLine removeFromSuperview];
        });
        
        self.signal = NO;
        [self.queue logDataWithMessage:@"deQueue"];
    });
}

- (UILabel *)nodeWithIndex:(NSInteger)index {
    if (self.nodeArray.count < index + 1) {
        return [self generateNode];
    }
    return self.nodeArray[index];
}

- (LineView *)lineWithIndex:(NSInteger)index {
    if (self.lineArray.count < index + 1) {
        return [self generateLine];
    }
    return self.lineArray[index];
}

- (UILabel *)generateNode {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kNodeSize, kNodeSize)];
    label.textAlignment = NSTextAlignmentCenter;
    label.layer.borderColor = [UIColor blackColor].CGColor;
    label.layer.borderWidth = 1;
    label.layer.cornerRadius = kNodeSize / 2;
    label.layer.masksToBounds = YES;
    [self.nodeArray addObject:label];
    return label;
}

- (LineView *)generateLine {
    LineView *line = [[LineView alloc] init];
    [self.lineArray addObject:line];
    return line;
}

@end
