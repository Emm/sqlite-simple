{-# LANGUAGE RecordWildCards #-}

------------------------------------------------------------------------------
-- |
-- Module:      Database.SQLite.Simple.FromRow
-- Copyright:   (c) 2011-2012 Leon P Smith
--              (c) 2012 Janne Hellsten
-- License:     BSD3
-- Maintainer:  Janne Hellsten <jjhellst@gmail.com>
-- Stability:   experimental
-- Portability: portable
--
-- The 'FromRow' typeclass, for converting a row of results
-- returned by a SQL query into a more useful Haskell representation.
--
-- Predefined instances are provided for tuples containing up to ten
-- elements.
------------------------------------------------------------------------------

module Database.SQLite.Simple.FromRow
     ( FromRow(..)
     , RowParser
     , field
     , fieldWith
     , numFieldsRemaining
     ) where

import           Control.Applicative (Applicative(..), (<$>))
import           Control.Exception (SomeException(..))
import           Control.Monad (replicateM)
import           Control.Monad.Trans.State.Strict
import           Control.Monad.Trans.Reader
import           Control.Monad.Trans.Class
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B

import           Database.SQLite.Simple.FromField
import           Database.SQLite.Simple.Internal
import           Database.SQLite.Simple.Ok
import           Database.SQLite.Simple.Types
import qualified Database.SQLite3 as Base

-- | A collection type that can be converted from a sequence of fields.
-- Instances are provided for tuples up to 10 elements and lists of any length.
--
-- Note that instances can defined outside of sqlite-simple,  which is
-- often useful.   For example, here's an instance for a user-defined pair:
--
-- @data User = User { name :: String, fileQuota :: Int }
--
-- instance 'FromRow' User where
--     fromRow = User \<$\> 'field' \<*\> 'field'
-- @
--
-- The number of calls to 'field' must match the number of fields returned
-- in a single row of the query result.  Otherwise,  a 'ConversionFailed'
-- exception will be thrown.
--
-- Note the caveats associated with user-defined implementations of
-- 'fromRow'.

class FromRow a where
    fromRow :: RowParser a

fieldWith :: FieldParser a -> RowParser a
fieldWith fieldP = RP $ do
    Row{..} <- ask
    column <- lift get
    lift (put (column + 1))
    let ncols = length rowresult
    if column >= ncols
    then do
      let vals = map (\c -> (gettypename (rowresult !! c)
                           , ellipsis (rowresult !! c)))
                     [0..ncols-1]
          convertError = ConversionFailed
              (show ncols ++ " values: " ++ show vals)
              ("at least " ++ show (column + 1)
                ++ " slots in target type")
              "mismatch between number of columns to \
              \convert and number in target type"
      lift (lift (Errors [SomeException convertError]))
    else do
      let r = rowresult !! column
          field = Field r column
      lift (lift (fieldP field))

field :: FromField a => RowParser a
field = fieldWith fromField

ellipsis :: Base.SQLData -> ByteString
ellipsis sql
    | B.length bs > 15 = B.take 10 bs `B.append` "[...]"
    | otherwise        = bs
  where
    bs = B.pack $ show sql

numFieldsRemaining :: RowParser Int
numFieldsRemaining = RP $ do
    Row{..} <- ask
    column <- lift get
    return $! length rowresult - column

instance (FromField a) => FromRow (Only a) where
    fromRow = Only <$> field

instance (FromField a, FromField b) => FromRow (a,b) where
    fromRow = (,) <$> field <*> field

instance (FromField a, FromField b, FromField c) => FromRow (a,b,c) where
    fromRow = (,,) <$> field <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d) =>
    FromRow (a,b,c,d) where
    fromRow = (,,,) <$> field <*> field <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e) =>
    FromRow (a,b,c,d,e) where
    fromRow = (,,,,) <$> field <*> field <*> field <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e,
          FromField f) =>
    FromRow (a,b,c,d,e,f) where
    fromRow = (,,,,,) <$> field <*> field <*> field <*> field <*> field
                      <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e,
          FromField f, FromField g) =>
    FromRow (a,b,c,d,e,f,g) where
    fromRow = (,,,,,,) <$> field <*> field <*> field <*> field <*> field
                       <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e,
          FromField f, FromField g, FromField h) =>
    FromRow (a,b,c,d,e,f,g,h) where
    fromRow = (,,,,,,,) <$> field <*> field <*> field <*> field <*> field
                        <*> field <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e,
          FromField f, FromField g, FromField h, FromField i) =>
    FromRow (a,b,c,d,e,f,g,h,i) where
    fromRow = (,,,,,,,,) <$> field <*> field <*> field <*> field <*> field
                         <*> field <*> field <*> field <*> field

instance (FromField a, FromField b, FromField c, FromField d, FromField e,
          FromField f, FromField g, FromField h, FromField i, FromField j) =>
    FromRow (a,b,c,d,e,f,g,h,i,j) where
    fromRow = (,,,,,,,,,) <$> field <*> field <*> field <*> field <*> field
                          <*> field <*> field <*> field <*> field <*> field

instance FromField a => FromRow [a] where
    fromRow = do
      n <- numFieldsRemaining
      replicateM n field

instance (FromRow a, FromRow b) => FromRow (a :. b) where
    fromRow = (:.) <$> fromRow <*> fromRow
