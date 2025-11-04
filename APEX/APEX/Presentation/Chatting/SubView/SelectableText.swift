import SwiftUI
import UIKit

struct SelectableText: UIViewRepresentable {
    var text: String
    var fontSize: CGFloat
    var textStyle: UIFont.TextStyle
    var lineSpacing: CGFloat
    var maxLayoutWidth: CGFloat
    var highlightQuery: String?

    init(_ text: String, fontSize: CGFloat, textStyle: UIFont.TextStyle, lineSpacing: CGFloat, maxLayoutWidth: CGFloat, highlightQuery: String? = nil) {
      self.text = text
      self.fontSize = fontSize
      self.textStyle = textStyle
      self.lineSpacing = lineSpacing
      self.maxLayoutWidth = maxLayoutWidth
      self.highlightQuery = highlightQuery
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
      textView.attributedText = buildAttributed(text: text, font: font, paragraphStyle: paragraphStyle, highlightQuery: highlightQuery)

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
      textView.attributedText = buildAttributed(text: text, font: font, paragraphStyle: paragraphStyle, highlightQuery: highlightQuery)
      textView.invalidateIntrinsicContentSize()
      textView.setNeedsLayout()
      textView.layoutIfNeeded()
    }

    private func buildAttributed(text: String, font: UIFont, paragraphStyle: NSParagraphStyle, highlightQuery: String?) -> NSAttributedString {
      let mas = NSMutableAttributedString(string: text)
      let full = NSRange(location: 0, length: (text as NSString).length)
      mas.addAttributes([
        .font: font,
        .paragraphStyle: paragraphStyle,
        .foregroundColor: UIColor.label
      ], range: full)

      if let q = highlightQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
        let nsText = text as NSString
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var searchRange = full
        while true {
          let found = nsText.range(of: q, options: options, range: searchRange)
          if found.location == NSNotFound { break }
          mas.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), range: found)
          let nextLoc = found.location + found.length
          if nextLoc >= nsText.length { break }
          searchRange = NSRange(location: nextLoc, length: nsText.length - nextLoc)
        }
      }
      return mas
    }
}
