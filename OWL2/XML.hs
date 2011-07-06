module OWL2.XML where

import Common.DocUtils
import Text.XML.Light
import Data.Maybe
import OWL2.AS
import OWL2.MS

import Data.List

entityList :: [String]
entityList = ["Class", "Datatype", "NamedIndividual",
    "ObjectProperty", "DataProperty", "AnnotationProperty"]

isEntity :: Text.XML.Light.QName -> Bool
isEntity (QName {qName = qn}) = qn `elem` entityList

isSmth :: String -> Text.XML.Light.QName -> Bool
isSmth s (QName {qName = qn}) = qn == s

getEntityType :: String -> EntityType
getEntityType ty = case ty of
    "Class" -> Class
    "Datatype" -> Datatype
    "NamedIndividual" -> NamedIndividual
    "ObjectProperty" -> ObjectProperty
    "DataProperty" -> DataProperty
    "AnnotationProperty" -> AnnotationProperty

getIRI :: Element -> OWL2.AS.QName
getIRI (Element {elAttribs = a}) =
        let Attr {attrVal = iri} = head a
        in mkQName iri

getName :: Element -> String
getName (Element {elName = QName {qName = n}}) = n

toEntity :: Element -> Entity
toEntity e = Entity (getEntityType $ getName e) (getIRI e)

getEntity :: Element -> Entity
getEntity e = toEntity $ fromJust $ filterElementName isEntity e

getDeclaration :: Element -> Frame
getDeclaration e = 
   let ent = fromJust $ filterChildName isEntity e
       ans = getAllAnnos e
   in Frame (Right $ toEntity ent) [AnnFrameBit ans AnnotationFrameBit]

getDeclarations :: Element -> [Frame]
getDeclarations e = 
   let dcl = filterElementsName (isSmth "Declaration") e
   in map getDeclaration dcl
     
isPlainLiteral :: String -> Bool
isPlainLiteral s = "PlainLiteral" == drop (length s - 12) s

getLiteral :: Element -> Literal
getLiteral e = let lit = fromJust $ filterElementName (isSmth "Literal") e
                   lf = strContent e
                   dt = fromJust $ findAttrBy (isSmth "datatypeIRI") lit
               in
                  case findAttrBy (isSmth "lang") lit of
                    Just lang -> Literal lf (Untyped $ Just lang)
                    Nothing -> if isPlainLiteral dt then
                                  Literal lf (Untyped Nothing)
                                else Literal lf (Typed $ mkQName dt)

getValue :: Element -> AnnotationValue
getValue e = let lit = filterElementName (isSmth "Literal") e
                 val = strContent e
             in case lit of
                  Nothing -> AnnValue $ mkQName val
                  Just _ -> AnnValLit $ getLiteral e

filterElem :: String -> Element -> [Element]
filterElem s = filterElementsName (isSmth s)

getAnnotation :: Element -> Annotation
getAnnotation e =
     let hd = filterChildrenName (isSmth "Annotation") e
         ap = filterElem "AnnotationProperty" e
         av = filterElem "Literal" e ++ filterElem "IRI" e
     in
          Annotation (getAnnotations hd)
              (getIRI $ head ap) (getValue $ head av)

getAnnotations :: [Element] -> [Annotation]
getAnnotations e = map getAnnotation $ concatMap
            (filterElementsName (isSmth "Annotation")) e

getAllAnnos :: Element -> [Annotation]
getAllAnnos e = map getAnnotation
            $ filterElementsName (isSmth "Annotation") e

getObjProp :: Element -> ObjectPropertyExpression
getObjProp e = case filterElementName (isSmth "ObjectInverseOf") e of
                  Nothing -> ObjectProp $ getIRI e
                  Just o -> ObjectInverseOf $ getObjProp $ head $ elChildren e

getFacetValuePair :: Element -> (ConstrainingFacet, RestrictionValue)
getFacetValuePair e = (getIRI e, getLiteral $ head $ elChildren e)

getDataRange :: Element -> DataRange
getDataRange e = case getName e of
    "Datatype" -> DataType (getIRI e) []
    "DatatypeRestriction" -> 
        let dt = getIRI $ fromJust $ filterChildName (isSmth "Datatype") e
            fvp = map getFacetValuePair
               $ filterChildrenName (isSmth "FacetRestriction") e
        in DataType dt fvp
    "DataComplementOf" -> DataComplementOf
            $ getDataRange $ head $ elChildren e
    "DataOneOf" -> DataOneOf
            $ map getLiteral $ filterChildrenName (isSmth "Literal") e
    "DataIntersectionOf" -> DataJunction IntersectionOf
            $ map getDataRange $ elChildren e
    "DataUnionOf" -> DataJunction UnionOf
            $ map getDataRange $ elChildren e



