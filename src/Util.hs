module Util where

safeHead :: [a] -> Maybe a
safeHead []    = Nothing
safeHead (x:_) = Just x
