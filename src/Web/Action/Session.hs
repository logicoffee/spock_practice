{-# LANGUAGE OverloadedStrings #-}
module Web.Action.Session where

import           Control.Monad.IO.Class     (liftIO)
import           Control.Monad.Trans.Except
import           Data.Aeson.Types
import           Data.Scientific            (scientific)
import           Data.Text.Encoding         (encodeUtf8)
import qualified Data.Text.Lazy             as TL
import           Data.Vault.Lazy
import           Model.AppUser.Entity
import           Model.AppUser.Insert
import           Model.AppUser.Query
import           Network.Wai
import           Util
import           Web.Scotty

import           Data.ByteString            (ByteString)
import qualified Data.Text                  as T
import qualified Data.Vault.Lazy            as V
import           Network.Wai.Session        (Session)

signupAction :: ActionM ()
signupAction = do
    tmpU <- TmpAppUser
        <$> param "name"
        <*> param "password"
        <*> param "password_confirmation"
    result <- liftIO $ runExceptT $ trySignup tmpU
    case result of
        Left msgs -> json $ object ["errors" .= map TL.toStrict msgs]
        Right uid -> json $ object ["user_id" .= Number (scientific (toInteger uid) 0)]

signinAction :: V.Key(Session IO T.Text ByteString) -> ActionM ()
signinAction key = do
    req <- request
    let Just (_, insertSession) = V.lookup key (vault req)

    n <- param "name"
    p <- param "password"
    maybeU <- liftIO $ findByName n
    case maybeU of
        Nothing -> json $ object ["errors" .= TL.toStrict "name or password is invalid"]
        Just u  -> if passwordHash u == hashPassword p
            then do
                liftIO $ insertSession "user" (encodeUtf8 (TL.toStrict n))
                json $ object ["user_id" .= Number (scientific (toInteger (Model.AppUser.Entity.id u)) 0)]
            else json $ object ["errors" .= TL.toStrict "name or password is invalid"]