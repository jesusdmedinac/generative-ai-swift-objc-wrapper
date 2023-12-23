// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// The model's response to a generate content request.
@objc public final class GenerateContentResponseObjC : NSObject {
  /// A list of candidate response content, ordered from best to worst.
  public var candidates: [CandidateResponseObjC]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public var promptFeedback: PromptFeedbackObjC?

  /// The response's content as text, if it exists.
  public var text: String? {
    guard let candidate = candidates.first else {
      Logging.default.error("Could not get text from a response that had no candidates.")
      return nil
    }
    guard let text = candidate.content.parts.first?.text else {
      Logging.default.error("Could not get a text part from the first candidate.")
      return nil
    }
    return text
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [CandidateResponseObjC], promptFeedback: PromptFeedbackObjC?) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
  }
}

extension GenerateContentResponseObjC: Decodable {
  enum CodingKeys: CodingKey {
    case candidates
    case promptFeedback
  }

  public convenience init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.contains(CodingKeys.candidates) || container
      .contains(CodingKeys.promptFeedback) else {
      let context = DecodingError.Context(
        codingPath: [],
        debugDescription: "Failed to decode GenerateContentResponse;" +
          " missing keys 'candidates' and 'promptFeedback'."
      )
      throw DecodingError.dataCorrupted(context)
    }
    var candidates: [CandidateResponseObjC]
    if let decodedCandidates = try container.decodeIfPresent(
      [CandidateResponseObjC].self,
      forKey: .candidates
    ) {
      candidates = decodedCandidates
    } else {
      candidates = []
    }
    var promptFeedback = try container.decodeIfPresent(PromptFeedbackObjC.self, forKey: .promptFeedback)
    self.init(candidates: candidates, promptFeedback: promptFeedback)
  }
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
@objc public final class CandidateResponseObjC : NSObject {
  /// The response's content.
  public var content: ModelContent

  /// The safety rating of the response content.
  public var safetyRatings: [SafetyRating]

  /// The reason the model stopped generating content, if it exists; for example, if the model
  /// generated a predefined stop sequence.
  public var finishReason: FinishReason?

  /// Cited works in the model's response content, if it exists.
  public var citationMetadata: CitationMetadata?

  /// Initializer for SwiftUI previews or tests.
  public init(content: ModelContent, safetyRatings: [SafetyRating], finishReason: FinishReason?,
              citationMetadata: CitationMetadata?) {
    self.content = content
    self.safetyRatings = safetyRatings
    self.finishReason = finishReason
    self.citationMetadata = citationMetadata
  }
}

extension CandidateResponseObjC: Decodable {
  enum CodingKeys: CodingKey {
    case content
    case safetyRatings
    case finishReason
    case finishMessage
    case citationMetadata
  }

  /// Initializes a response from a decoder. Used for decoding server responses; not for public
  /// use.
  public convenience init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    var content: ModelContent
    do {
      if let decodedContent = try container.decodeIfPresent(ModelContent.self, forKey: .content) {
        content = decodedContent
      } else {
        content = ModelContent(parts: [])
      }
    } catch {
      // Check if `content` can be decoded as an empty dictionary to detect the `"content": {}` bug.
      if let content = try? container.decode([String: String].self, forKey: .content),
         content.isEmpty {
        throw InvalidCandidateError.emptyContent(underlyingError: error)
      } else {
        throw InvalidCandidateError.malformedContent(underlyingError: error)
      }
    }

    var safetyRatings: [SafetyRating]
    if let decodedSafetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      safetyRatings = decodedSafetyRatings
    } else {
      safetyRatings = []
    }

    var finishReason = try container.decodeIfPresent(FinishReason.self, forKey: .finishReason)

    var citationMetadata = try container.decodeIfPresent(
      CitationMetadata.self,
      forKey: .citationMetadata
    )
    self.init(content: content, safetyRatings: safetyRatings, finishReason: finishReason, citationMetadata: citationMetadata)
  }
}

/// A collection of source attributions for a piece of content.
@objc public final class CitationMetadataObjC: NSObject, Decodable {
  /// A list of individual cited sources and the parts of the content to which they apply.
  public var citationSources: [Citation]
  
  init(citationSources: [Citation]) {
    self.citationSources = citationSources
  }
}

/// A struct describing a source attribution.
@objc public class CitationObjC: NSObject, Decodable {
  /// The inclusive beginning of a sequence in a model response that derives from a cited source.
  public var startIndex: Int

  /// The exclusive end of a sequence in a model response that derives from a cited source.
  public var endIndex: Int

  /// A link to the cited source.
  public var uri: String

  /// The license the cited source work is distributed under.
  public var license: String
  
  init(startIndex: Int, endIndex: Int, uri: String, license: String) {
    self.startIndex = startIndex
    self.endIndex = endIndex
    self.uri = uri
    self.license = license
  }
}

/// A value enumerating possible reasons for a model to terminate a content generation request.
@objc public enum FinishReasonObjC: Int {
  case unknown = -1 // "FINISH_REASON_UNKNOWN"

  case unspecified = 0 // "FINISH_REASON_UNSPECIFIED"

  /// Natural stop point of the model or provided stop sequence.
  case stop = 1 // "STOP"

  /// The maximum number of tokens as specified in the request was reached.
  case maxTokens = 2 // "MAX_TOKENS"

  /// The token generation was stopped because the response was flagged for safety reasons.
  /// NOTE: When streaming, the Candidate.content will be empty if content filters blocked the
  /// output.
  case safety = 3 // "SAFETY"

  /// The token generation was stopped because the response was flagged for unauthorized citations.
  case recitation = 4 // "RECITATION"

  /// All other reasons that stopped token generation.
  case other = 5 // "OTHER"
}

extension FinishReasonObjC: Decodable {
  /// Do not explicitly use. Initializer required for Decodable conformance.
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(Int.self)
    guard let decodedFinishReason = FinishReasonObjC(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized FinishReason with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedFinishReason
  }
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
@objc public final class PromptFeedbackObjC : NSObject, Decodable {
  /// A type describing possible reasons to block a prompt.
  public enum BlockReason: String, Decodable {
    /// The block reason is unknown.
    case unknown = "UNKNOWN"

    /// The block reason was not specified in the server response.
    case unspecified = "BLOCK_REASON_UNSPECIFIED"

    /// The prompt was blocked because it was deemed unsafe.
    case safety = "SAFETY"

    /// All other block reasons.
    case other = "OTHER"

    /// Do not explicitly use. Initializer required for Decodable conformance.
    public init(from decoder: Decoder) throws {
      let value = try decoder.singleValueContainer().decode(String.self)
      guard let decodedBlockReason = BlockReason(rawValue: value) else {
        Logging.default
          .error("[GoogleGenerativeAI] Unrecognized BlockReason with value \"\(value)\".")
        self = .unknown
        return
      }

      self = decodedBlockReason
    }
  }

  /// The reason a prompt was blocked, if it was blocked.
  public let blockReason: BlockReason?

  /// The safety ratings of the prompt.
  public let safetyRatings: [SafetyRating]

  /// Initializer for SwiftUI previews or tests.
  public init(blockReason: BlockReason?, safetyRatings: [SafetyRating]) {
    self.blockReason = blockReason
    self.safetyRatings = safetyRatings
  }

  enum CodingKeys: CodingKey {
    case blockReason
    case safetyRatings
  }

  /// Do not explicitly use. Initializer required for Decodable conformance.
  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    blockReason = try container.decodeIfPresent(
      PromptFeedbackObjC.BlockReason.self,
      forKey: .blockReason
    )
    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }
  }
}

