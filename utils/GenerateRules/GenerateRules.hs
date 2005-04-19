{-| 
Module      :  $Header$
Copyright   :  (c) Felix Reckers, Uni Bremen 2002-2004
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  portable
-}

module Main where

import System.Console.GetOpt
import System.Directory
import System.Environment
import Text.ParserCombinators.Parsec
import ParseFile
import ParseHeader
import Data.List

data Flag = Rule String | Exclude String | Header String 
          | Output_Directory String deriving Show

options :: [OptDescr Flag]
options = [
           Option ['r'] ["rule"] (ReqArg Rule "RULE") 
                   "rules are the actual DrIFT derivations",
           Option ['x'] ["exclude"] (ReqArg Exclude "data[:data]") 
            "excludes the specified data-types",
           Option ['h'] ["header"] (ReqArg Header "FILE[:FILE]")
            "uses the header-file(s) for generation, parses them and \
            \omits the rules for the instances in the header(s)",
           Option ['o'] ["output-directory"] (ReqArg Output_Directory "DIR") 
            "specifies the output-directory"
          ]

main :: IO ()
main = do args <- getArgs
          case (getOpt RequireOrder options args) of
            (m,n,[]) -> case n of
                         []  -> ioError $ userError ("no filename specified\n" 
                                         ++ usageInfo header options)
                         fs -> genRules m fs
            (_,_,errs) -> ioError (userError (concat errs 
                                              ++ usageInfo header options))
       where header = "Usage: genRules [OPTION...] file [file ...]" 

{- | if output dir is "ATC" then create an equally named .der.hs file
   otherwise create "<dir>.ATC_<dir> module. -}
genRules :: [Flag] -> [FilePath] -> IO ()
genRules flags files = 
    do i_ds <- mapM readParseFile files
       (rule,dir) <- getRuleAndDir flags
       let fileWP = if dir == "ATC" 
                    then cutSuffixBasename $ head files
                    else "ATC_" ++ dir
           fName = dir ++ "/" ++ fileWP ++ ".der.hs"
       fps <- getPaths flags 
       headers <- mapM readFile fps
       exc <- parseHeader (concat headers) 
       let (ds,imports) = ((\ (x,y) -> (concat x,concat y)) . unzip) i_ds
       ds' <- exclude flags exc ds 
       let fileHead = 
             "{- |\nModule      :  " ++ fName ++
             "\nCopyright   :  (c) Uni Bremen 2004" ++
             "\nLicence     :  similar to LGPL, see HetCATS/LICENCE.txt" ++
             "\n\nMaintainer  :  hets@tzi.de" ++
             "\nStability   :  provisional" ++
             "\nPortability :  portable\n" ++
             "\n  Automatic derivation of instances via DrIFT-rule " ++ 
                   rule ++ 
             "\n  for the type(s):" ++ 
                   concatMap ( \ t -> " '" ++ t ++ "'") ds' ++
             "\n-}\n" ++ "{-\n  Generated by 'genRules' " ++ 
             "(automatic rule generation for DrIFT). Don't touch!!" ++ 
             "\n  dependency files: " ++ unwords files ++ "\n-}"
       imports' <- checkImports fileWP ("Common.ATerm.Lib":imports)
       writeFile fName
                 (fileHead ++ "\n\nmodule " ++ dir ++ "." 
                  ++ fileWP
                  ++ " where\n\n" 
                  ++ (if elem dir ["Modal", "CoCASL", "COL", "CspCASL"] then 
                             "import CASL.ATC_CASL\n" else "")  
                  ++ concat (map (\x->"import "++x++"\n") 
                                            imports') 
                  ++ "\n" ++ concat headers ++ "\n" 
                  ++ rules rule ds' ++ "\n")
                          
readParseFile :: FilePath -> IO ([Data],[Import])
readParseFile fp =
    do inp <- readFile fp
       y <- case parseInputFile fp inp of
         Left err -> do putStr "parse error at "
                        fail err
         Right x  -> return x
       return y

firstdirname :: FilePath -> FilePath
firstdirname fp = (fst $ break (== '/') fp) ++ "/"

parseHeader :: String -> IO [Exclude]
parseHeader [] = return []
parseHeader hs = case (parse header "" hs) of
                    Left err -> do putStrLn "parse error at "
                                   print err
                                   return []
                    Right x  -> return x 

checkImports :: String -> [Import] -> IO [Import]  
checkImports fn xs = do let imports = nub xs
                            importsATC = 
                                map (\x-> "ATC."
                                          ++ (cutModuleName x)) imports
                        bools <- mapM doesFileExist (map (\x->"ATC/"
                                 ++cutModuleName x++".der.hs") importsATC) 
                        return $ checkSpecialImports fn 
                            (imports ++ (filter (/=[]) 
                               (map selectTrue (zip bools importsATC))))
                     where 
                     selectTrue :: (Bool,String) -> String
                     selectTrue (True,x) = x
                     selectTrue (False,x) = []
                  
checkSpecialImports :: String -> [Import] -> [Import]
checkSpecialImports fn []     = []
checkSpecialImports fn (x:xs) | x == "Logic.Grothendieck" = 
                                  x : "ATC.Grothendieck" : ys
                              | x == "ATC."++fn           = ys
                              | otherwise                 = x : ys
    where ys = checkSpecialImports fn xs

cutModuleName :: FilePath -> FilePath
cutModuleName fp = reverse $ remP $ fst $ break (=='.') (reverse fp)
    where remP [] = [] 
          remP xs@(x:xs1) 
              | x == '.' = xs1
              | otherwise = xs

rules :: String -> [String] -> String
rules rule []     = []
rules rule (d:ds) = "{-! for " ++ d ++ " derive : " ++ rule ++ " !-}\n" 
                    ++ rules rule ds

exclude :: [Flag] -> [Data] -> [Data] -> IO [String]
exclude []               exc ds = return [ d | d <- ds,not (elem d exc) ]
exclude ((Exclude s):fs) exc ds = 
    case (parse (sepBy1 identifier (char ':')) "" s) of
    Left err -> do putStr "can't parse exclude datatypes"
                   print err
                   return []
    Right excs  -> return [ d | d <- ds,not (elem d excs),not (elem d exc) ]
exclude (_:fs)           exc ds = exclude fs exc ds 

getPaths :: [Flag] -> IO [FilePath]
getPaths []              = return []
getPaths ((Header s):fs) = 
    case (parse (sepBy1 path (char ':')) "" s) of
    Left err -> do putStr "couldn't parse header-files"
                   print err
                   return []
    Right x  -> return x
getPaths (_:fs)          = getPaths fs

path :: Parser FilePath
path = many1 (noneOf ":*+?<>")

dirName :: Parser String
dirName = many1 (noneOf "/*+?<>")

getRuleAndDir :: [Flag] -> IO (String,String)
getRuleAndDir flags = return (getRule flags,getDir flags)
                      where
                      getRule ((Rule s):_) = s
                      getRule (_:xs)       = getRule xs
                      getDir ((Output_Directory s):_) = s
                      getDir (_:xs)                   = getDir xs

cutSuffixBasename :: String -> String
cutSuffixBasename = takeWhile (/= '.') . reverse . takeWhile (/= '/') . reverse
