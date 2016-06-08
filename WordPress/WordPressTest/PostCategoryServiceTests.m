#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import "Blog.h"
#import "PostCategory.h"
#import "PostCategoryService.h"
#import "TaxonomyServiceRemoteREST.h"
#import "RemoteTaxonomyPaging.h"
#import "RemotePostCategory.h"
#import "WordPress-Swift.h"

@interface PostCategoryServiceForStubbing : PostCategoryService

@property (nonatomic, strong) TaxonomyServiceRemoteREST *remoteForStubbing;

@end

@implementation PostCategoryServiceForStubbing

- (id <TaxonomyServiceRemote>)remoteForBlog:(Blog *)blog
{
    return self.remoteForStubbing;
}

@end

@interface PostCategoryServiceTests : XCTestCase

@property (nonatomic, strong) Blog *blog;
@property (nonatomic, strong) PostCategoryServiceForStubbing *service;

@end

@implementation PostCategoryServiceTests

- (void)setUp
{
    [super setUp];
    
    WordPressComRestApi *api = OCMStrictClassMock([WordPressComRestApi class]);
    
    Blog *blog = OCMStrictClassMock([Blog class]);
    
    OCMStub([blog wordPressComRestApi]).andReturn(api);
    OCMStub([blog dotComID]).andReturn(@1);
    OCMStub([blog objectID]).andReturn(nil);
    
    self.blog = blog;
    
    NSManagedObjectContext *context = OCMStrictClassMock([NSManagedObjectContext class]);
    
    PostCategoryServiceForStubbing *service = [[PostCategoryServiceForStubbing alloc] initWithManagedObjectContext:context];
    
    TaxonomyServiceRemoteREST *remoteService = OCMStrictClassMock([TaxonomyServiceRemoteREST class]);
    service.remoteForStubbing = remoteService;
    
    self.service = service;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    self.blog = nil;
    self.service = nil;
}

- (void)testThatSyncCategoriesWorks
{
    TaxonomyServiceRemoteREST *remote = self.service.remoteForStubbing;
    OCMStub([remote getCategoriesWithSuccess:[OCMArg isNotNil]
                                     failure:[OCMArg isNotNil]]);
    
    [self.service syncCategoriesForBlog:self.blog
                                success:^{}
                                failure:^(NSError * _Nonnull error) {}];
}

- (void)testThatSyncCategoriesWithPagingWorks
{
    TaxonomyServiceRemoteREST *remote = self.service.remoteForStubbing;
    
    NSNumber *number = @120;
    NSNumber *offset = @30;
    
    BOOL (^pagingCheckBlock)(id obj) = ^BOOL(RemoteTaxonomyPaging *paging) {
        if (![paging.number isEqual:number]) {
            return NO;
        }
        if (![paging.offset isEqual:offset]) {
            return NO;
        }
        return YES;
    };
    OCMStub([remote getCategoriesWithPaging:[OCMArg checkWithBlock:pagingCheckBlock]
                                    success:[OCMArg isNotNil]
                                    failure:[OCMArg isNotNil]]);
    
    [self.service syncCategoriesForBlog:self.blog
                                 number:number
                                 offset:offset
                                success:^(NSArray<PostCategory *> * _Nonnull tags) {}
                                failure:^(NSError * _Nonnull error) {}];
}

- (void)testThatCreateCategoryWithNameWorks
{
    TaxonomyServiceRemoteREST *remote = self.service.remoteForStubbing;

    NSString *name = @"category name";
    
    BOOL (^remoteCategoryCheckBlock)(id obj) = ^BOOL(RemotePostCategory *category) {
        if (![category.name isEqualToString:name]) {
            return NO;
        }
        return YES;
    };
    OCMStub([remote createCategory:[OCMArg checkWithBlock:remoteCategoryCheckBlock]
                           success:[OCMArg isNotNil]
                           failure:[OCMArg isNotNil]]);
    
    [self.service createCategoryWithName:name
                  parentCategoryObjectID:nil
                         forBlogObjectID:self.blog.objectID
                                 success:^(PostCategory * _Nonnull category) {}
                                 failure:^(NSError * _Nonnull error) {}];
}

@end
