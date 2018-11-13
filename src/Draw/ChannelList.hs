{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE RankNTypes #-}

-- | This module provides the Drawing functionality for the
-- ChannelList sidebar.  The sidebar is divided vertically into groups
-- and each group is rendered separately.
--
-- There are actually two UI modes handled by this code:
--
--   * Normal display of the channels, with various markers to
--     indicate the current channel, channels with unread messages,
--     user state (for Direct Message channels), etc.
--
--   * ChannelSelect display where the user is typing match characters
--     into a prompt at the ChannelList sidebar is showing only those
--     channels matching the entered text (and highlighting the
--     matching portion).

module Draw.ChannelList (renderChannelList) where

import           Prelude ()
import           Prelude.MH

import           Brick
import           Brick.Widgets.Border
import           Brick.Widgets.Center (hCenter)
import qualified Data.Sequence as Seq
import qualified Data.Foldable as F
import qualified Data.HashMap.Strict as HM
import qualified Data.Text as T
import           Lens.Micro.Platform (Getting, at, non)

import           Draw.Util
import           State.Channels
import           Themes
import           Types
import qualified Zipper as Z

type GroupName = Text

-- | Internal record describing each channel entry and its associated
-- attributes.  This is the object passed to the rendering function so
-- that it can determine how to render each channel.
data ChannelListEntryData =
    ChannelListEntryData { entrySigil       :: Text
                         , entryLabel       :: Text
                         , entryHasUnread   :: Bool
                         , entryMentions    :: Int
                         , entryIsRecent    :: Bool
                         , entryIsCurrent   :: Bool
                         , entryUserStatus  :: Maybe UserStatus
                         }

-- | Similar to the ChannelListEntryData, but also holds information
-- about the matching channel select specification.
data SelectedChannelListEntry = SCLE ChannelListEntryData ChannelSelectMatch

renderChannelList :: ChatState -> Widget Name
renderChannelList st =
    viewport ChannelList Vertical $
        vBox groups
    where
        groups = case appMode st of
            ChannelSelect ->
                let zipper = st^.csChannelSelectState.channelSelectMatches
                in if Z.isEmpty zipper
                   then [hCenter $ txt "No matches"]
                   else renderChannelListGroup st (renderChannelSelectListEntry (Z.focus zipper)) <$>
                        Z.toList zipper
            _ ->
                renderChannelListGroup st (\st e -> renderChannelListEntry $ mkChannelEntryData st e) <$>
                    Z.toList (st^.csFocus)

renderChannelListGroupHeading :: ChannelListGroup -> Widget Name
renderChannelListGroupHeading g =
    let label = case g of
            ChannelGroupPublicChannels -> "Public Channels"
            ChannelGroupDirectMessages -> "Direct Messages"
    in hBorderWithLabel $ withDefAttr channelListHeaderAttr $ txt label

renderChannelListGroup :: ChatState
                       -> (ChatState -> e -> Widget Name)
                       -> (ChannelListGroup, [e])
                       -> Widget Name
renderChannelListGroup st renderEntry (group, es) =
    let heading = renderChannelListGroupHeading group
        entryWidgets = renderEntry st <$> es
    in if null entryWidgets
       then emptyWidget
       else vBox (heading : entryWidgets)

mkChannelEntryData :: ChatState
                   -> ChannelListEntry
                   -> ChannelListEntryData
mkChannelEntryData st e =
    ChannelListEntryData sigil name unread mentions recent current status
    where
        cId = channelListEntryChannelId e
        unread = hasUnread st cId
        recent = isRecentChannel st cId
        current = isCurrentChannel st cId
        (name, normalSigil, status) = case e of
            CLChannel _ ->
                let Just chan = findChannelById cId (st^.csChannels)
                in (chan^.ccInfo.cdName, normalChannelSigil, Nothing)
            CLUser _ uId ->
                let Just u = userById uId st
                    uname = if useNickname st
                            then u^.uiNickName.non (u^.uiName)
                            else u^.uiName
                in (uname, T.cons (userSigilFromInfo u) " ", Just $ u^.uiStatus)
        sigil = case st^.csEditState.cedLastChannelInput.at cId of
            Nothing      -> normalSigil
            Just ("", _) -> normalSigil
            _            -> "»"
        mentions = channelMentionCount cId st

-- | Render an individual Channel List entry (in Normal mode) with
-- appropriate visual decorations.
renderChannelListEntry :: ChannelListEntryData -> Widget Name
renderChannelListEntry entry =
    decorate $ decorateRecent entry $ decorateMentions $ padRight Max $
    entryWidget $ entrySigil entry <> entryLabel entry
    where
    decorate = if | entryIsCurrent entry ->
                      visible . forceAttr currentChannelNameAttr
                  | entryMentions entry > 0 ->
                      forceAttr mentionsChannelAttr
                  | entryHasUnread entry ->
                      forceAttr unreadChannelAttr
                  | otherwise -> id
    entryWidget = case entryUserStatus entry of
                    Just Offline -> withDefAttr clientMessageAttr . txt
                    Just _       -> colorUsername (entryLabel entry)
                    Nothing      -> txt
    decorateMentions
      | entryMentions entry > 9 =
        (<+> str "(9+)")
      | entryMentions entry > 0 =
        (<+> str ("(" <> show (entryMentions entry) <> ")"))
      | otherwise = id

-- | Render an individual entry when in Channel Select mode,
-- highlighting the matching portion, or completely suppressing the
-- entry if it doesn't match.
renderChannelSelectListEntry :: Maybe ChannelSelectMatch -> ChatState -> ChannelSelectMatch -> Widget Name
renderChannelSelectListEntry curMatch st match =
    let ChannelSelectMatch preMatch inMatch postMatch fullName entry = match
        maybeSelect = if (Just entry) == (matchEntry <$> curMatch)
                      then visible . withDefAttr currentChannelNameAttr
                      else id
        entryData = mkChannelEntryData st entry
    in maybeSelect $
       decorateRecent entryData $
       padRight Max $
         hBox [ txt $ entrySigil entryData <> preMatch
              , forceAttr channelSelectMatchAttr $ txt inMatch
              , txt postMatch
              ]

-- | If this channel is the most recently viewed channel (prior to the
-- currently viewed channel), add a decoration to denote that.
decorateRecent :: ChannelListEntryData -> Widget n -> Widget n
decorateRecent entry = if entryIsRecent entry
                       then (<+> (withDefAttr recentMarkerAttr $ str "<"))
                       else id
