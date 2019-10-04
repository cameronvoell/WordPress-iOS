import UIKit
import XCTest
import Nimble

@testable import WordPress

class PostCoordinatorTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = TestContextManager().newDerivedContext()
        TestAnalyticsTracker.setup()
    }

    override func tearDown() {
        super.tearDown()
        TestAnalyticsTracker.tearDown()
        context = nil
    }

    func testDoNotUploadAPostWithFailedMedia() {
        let postServiceMock = PostServiceMock()
        let post = PostBuilder(context)
            .with(image: "test.jpeg", status: .failed)
            .with(remoteStatus: .local)
            .build()
        let mediaCoordinatorMock = MediaCoordinatorMock(media: post.media.first!, mediaState: .failed(error: NSError()))
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock, mediaCoordinator: mediaCoordinatorMock)

        postCoordinator.save(post)

        expect(postServiceMock.didCallMarkAsFailedAndDraftIfNeeded).toEventually(beTrue())
        expect(postServiceMock.didCallUploadPost).to(beFalse())
    }

    func testUploadAPostWithNoFailedMedia() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        let post = PostBuilder(context)
            .with(image: "test.jpeg")
            .build()

        postCoordinator.save(post)

        expect(postServiceMock.didCallUploadPost).to(beTrue())
    }

    func testEventuallyMarkThePostRemoteStatusAsUploading() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        let post = PostBuilder(context)
            .with(image: "test.jpeg")
            .build()

        postCoordinator.save(post)

        expect(post.remoteStatus).toEventually(equal(.pushing))
    }

    func testAttemptCountIsIncrementedAfterFailingToAutomaticallyUpload() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        let post = PostBuilder(context).build()

        postCoordinator.save(post, automatedRetry: true)

        expect(post.autoUploadAttemptsCount).to(equal(1))
    }

    func testAttemptCountIsResetWhenNotAutomaticallyUpload() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        let post = PostBuilder(context).with(autoUploadAttemptsCount: 3).build()

        postCoordinator.save(post, automatedRetry: false)

        expect(post.autoUploadAttemptsCount).to(equal(0))
    }

    func testResumeWillAutoSaveUnconfirmedExistingPosts() {
        let postServiceMock = PostServiceMock(managedObjectContext: context)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        _ = PostBuilder(context)
            .withRemote()
            .with(status: .draft)
            .with(remoteStatus: .failed)
            .build()
        try! context.save()

        postCoordinator.resume()

        expect(postServiceMock.didCallAutoSave).toEventually(beTrue())
    }

    func testCancelAutoUploadOfAPost() {
        let post = PostBuilder(context).confirmedAutoUpload().build()
        let postServiceMock = PostServiceMock(managedObjectContext: context)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)

        postCoordinator.cancelAutoUploadOf(post)

        expect(post.shouldAttemptAutoUpload).to(beFalse())
    }

    func testCancelAutoUploadChangePostStatusToDraftWhenPostDoesntHasRemote() {
        let post = PostBuilder(context)
            .with(status: .pending)
            .with(remoteStatus: .failed)
            .build()
        let postServiceMock = PostServiceMock(managedObjectContext: context)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)

        postCoordinator.cancelAutoUploadOf(post)

        expect(post.status).to(equal(.draft))
    }

    func testCancelAutoUploadDoNotChangePostStatusToDraftWhenPostHasRemote() {
        let post = PostBuilder(context)
            .withRemote()
            .with(status: .publish)
            .with(remoteStatus: .failed)
            .build()
        let postServiceMock = PostServiceMock(managedObjectContext: context)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)

        postCoordinator.cancelAutoUploadOf(post)

        expect(post.status).to(equal(.publish))
    }
    
    func testTracksAutoUploadPostInvoked() {
        let postServiceMock = PostServiceMock(managedObjectContext: context)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, backgroundService: postServiceMock)
        let interactor = PostAutoUploadInteractor()
        let post = PostBuilder(context)
            .withRemote()
            .with(status: .draft)
            .with(remoteStatus: .failed)
            .build()
        try! context.save()

        postCoordinator.resume()
        guard let status = post.status else {
            return
        }

        expect(TestAnalyticsTracker.tracked.count).toEventually(equal(1))
        let trackEvent = TestAnalyticsTracker.tracked.first
        expect(trackEvent?.stat).toEventually(equal(WPAnalyticsStat.autoUploadPostInvoked))

        let propertyAction = trackEvent?.properties["upload_action"] as? String
        let action = interactor.autoUploadAction(for: post)
        expect(propertyAction).toEventually(equal(action.rawValue))

        let propertyStatus = trackEvent?.properties["post_status"] as? String
        expect(propertyStatus).toEventually(equal(status.rawValue))
    }
}

private class PostServiceMock: PostService {
    private(set) var didCallUploadPost = false
    private(set) var didCallMarkAsFailedAndDraftIfNeeded = false
    private(set) var didCallAutoSave = false

    override func uploadPost(_ post: AbstractPost, success: ((AbstractPost) -> Void)?, failure: @escaping (Error?) -> Void) {
        didCallUploadPost = true
    }

    override func autoSave(_ post: AbstractPost, success: ((AbstractPost, String) -> Void)?, failure: @escaping (Error?) -> Void) {
        didCallAutoSave = true
    }

    override func markAsFailedAndDraftIfNeeded(post: AbstractPost) {
        didCallMarkAsFailedAndDraftIfNeeded = true
    }
}

private class MediaCoordinatorMock: MediaCoordinator {
    var media: Media
    var mediaState: MediaState

    init(media: Media, mediaState: MediaState) {
        self.media = media
        self.mediaState = mediaState
    }

    override func addObserver(_ onUpdate: @escaping MediaCoordinator.ObserverBlock, for media: Media? = nil) -> UUID {
        return UUID()
    }

    override func addObserver(_ onUpdate: @escaping MediaCoordinator.ObserverBlock, forMediaFor post: AbstractPost) -> UUID {
        onUpdate(self.media, mediaState)
        return UUID()
    }

    override func retryMedia(_ media: Media, automatedRetry: Bool = false, analyticsInfo: MediaAnalyticsInfo? = nil) {
        // noop
    }
}
