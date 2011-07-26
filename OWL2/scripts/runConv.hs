import System.Environment

import OWL2.XML
import OWL2.XMLConversion
import Text.XML.Light
import OWL2.Print()
import OWL2.ManchesterPrint()

processFile :: String -> IO ()
processFile file = do
    s <- readFile file
    let elems = map xmlBasicSpec
                $ concatMap (filterElementsName $ isSmth "Ontology")
                $ onlyElems $ parseXML s
    mapM_ (putStrLn . ppElement . xmlOntologyDoc) elems

main :: IO ()
main = do
    args <- getArgs
    mapM_ processFile args