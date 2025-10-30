import SwiftUI
import UIKit

struct SelectableText: UIViewRepresentable {
    var text: String
    var fontSize: CGFloat
    var textStyle: UIFont.TextStyle
    var lineSpacing: CGFloat
    var maxLayoutWidth: CGFloat

    init(_ text: String, fontSize: CGFloat, textStyle: UIFont.TextStyle, lineSpacing: CGFloat, maxLayoutWidth: CGFloat) {
      self.text = text
      self.fontSize = fontSize
      self.textStyle = textStyle
      self.lineSpacing = lineSpacing
      self.maxLayoutWidth = maxLayoutWidth
    }

    func makeUIView(context: Context) -> UITextView {
      let textView = UITextView()
      textView.translatesAutoresizingMaskIntoConstraints = false
      textView.isScrollEnabled = false
      textView.isEditable = false
      textView.isSelectable = true
      textView.dataDetectorTypes = .link
      textView.backgroundColor = .clear
      textView.textContainer.lineBreakMode = .byWordWrapping
      textView.textContainer.lineFragmentPadding = 0
      textView.textContainerInset = .zero
      textView.setContentHuggingPriority(.required, for: .horizontal)
      textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      textView.setContentCompressionResistancePriority(.required, for: .vertical)

      // Constrain width to not exceed maxLayoutWidth while allowing it to hug content width
      let widthId = "SelectableTextMaxWidth"
      if let existing = textView.constraints.first(where: { $0.identifier == widthId }) {
        existing.isActive = false
        textView.removeConstraint(existing)
      }
      let maxWidth = textView.widthAnchor.constraint(lessThanOrEqualToConstant: maxLayoutWidth)
      maxWidth.identifier = widthId
      maxWidth.priority = UILayoutPriority(999)
      maxWidth.isActive = true

      // 글꼴 및 줄 간격 설정
      let fontName = Font.PretendardWeight.medium.fontName // 커스텀 글꼴 이름
      var font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

      let metrics = UIFontMetrics(forTextStyle: textStyle)
      font = metrics.scaledFont(for: font)

      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = lineSpacing
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle,
        .foregroundColor: UIColor.label
      ]
      let attributedString = NSAttributedString(string: text, attributes: attributes)
      textView.attributedText = attributedString

      textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      textView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
      return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
      // Update width constraint
      let widthId = "SelectableTextMaxWidth"
      if let existing = textView.constraints.first(where: { $0.identifier == widthId }) {
        existing.constant = maxLayoutWidth
      } else {
        let maxWidth = textView.widthAnchor.constraint(lessThanOrEqualToConstant: maxLayoutWidth)
        maxWidth.identifier = widthId
        maxWidth.priority = UILayoutPriority(999)
        maxWidth.isActive = true
      }

      // Update text attributes
      let fontName = Font.PretendardWeight.medium.fontName
      var font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
      let metrics = UIFontMetrics(forTextStyle: textStyle)
      font = metrics.scaledFont(for: font)

      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = lineSpacing
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle,
        .foregroundColor: UIColor.label
      ]
      textView.attributedText = NSAttributedString(string: text, attributes: attributes)
      textView.invalidateIntrinsicContentSize()
      textView.setNeedsLayout()
      textView.layoutIfNeeded()
    }
}
