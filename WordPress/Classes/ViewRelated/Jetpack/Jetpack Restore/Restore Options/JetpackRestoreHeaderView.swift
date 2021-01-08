import Foundation
import Gridicons
import WordPressUI

class JetpackRestoreHeaderView: UIView, NibReusable {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var body: UILabel!
    @IBOutlet weak var actionButton: FancyButton!

    var actionButtonHandler: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyles()
    }

    private func applyStyles() {
        icon.tintColor = .success

        title.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
        title.textColor = .text

        body.font = WPStyleGuide.fontForTextStyle(.body)
        body.textColor = .textSubtle
        body.numberOfLines = 0
        // Need to define preferredMaxLayoutWidth for multiline labels in a custom tableHeaderView
        body.preferredMaxLayoutWidth = body.bounds.width
        
        actionButton.isPrimary = true
    }

    func configure(site: JetpackSiteRef,
                   formattableActivity: FormattableActivity,
                   restoreAction: JetpackRestoreAction) {

        let dateFormatter = ActivityDateFormatting.mediumDateFormatterWithTime(for: site)
        let publishedDate = dateFormatter.string(from: formattableActivity.activity.published)

        switch restoreAction {
        case .restore:
            icon.image = UIImage.gridicon(.history)
            title.text = NSLocalizedString("Restore site", comment: "Label that describes the restore site action")
            let descriptionFormat = NSLocalizedString("%1$@ is the selected point for your restore.", comment: "Description for the restore action. $1$@ is a placeholder for the selected date.")
            body.text = String(format: descriptionFormat, publishedDate)
            actionButton.setTitle(NSLocalizedString("Restore to this point", comment: "Button title for restore site action"), for: .normal)
        case .downloadBackup:
            icon.image = UIImage.gridicon(.history)
            title.text = NSLocalizedString("Create downloadable backup", comment: "Label that describes the download backup action")
            let descriptionFormat = NSLocalizedString("%1$@ is the selected point to create a downloadable backup.", comment: "Description for the download backup action. $1$@ is a placeholder for the selected date.")
            body.text = String(format: descriptionFormat, publishedDate)
            actionButton.setTitle(NSLocalizedString("Create downloadable file", comment: "Button title for download backup action"), for: .normal)
        }
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        actionButtonHandler?()
    }
}
