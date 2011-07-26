{- |
Module      :  $Header$
Copyright   :  (c) Felix Gabriel Mance
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.mance@jacobs-university.de
Stability   :  provisionalM
Portability :  portable

Conversion from Manchester syntax to XML Syntax
-}

module OWL2.XMLConversion where

import OWL2.AS
import OWL2.MS
import OWL2.XML
import OWL2.ManchesterPrint
import OWL2.Sign
import OWL2.XMLKeywords

import Text.XML.Light
import Data.Maybe
import Common.Id
import Common.AS_Annotation (Named, sentence)

import qualified Data.Map as Map

showIRI :: OWL2.AS.QName -> String
showIRI (QN pre local _ _ _) = pre ++ ":" ++ local

nullQN :: Text.XML.Light.QName
nullQN = QName "" Nothing Nothing

makeQN :: String -> Text.XML.Light.QName
makeQN s = nullQN {qName = s}

setQNPrefix :: String -> Text.XML.Light.QName -> Text.XML.Light.QName
setQNPrefix s qn = qn {qPrefix = Just s}

nullElem :: Element
nullElem = Element nullQN [] [] Nothing

setIRI :: IRI -> Element -> Element
setIRI iri e =
    let np = namePrefix iri
        ty
            | isAnonymous iri = "nodeID"
            | isFullIri iri {-|| null np-} = iriK
            | otherwise = "abbreviatedIRI"
    in e {elAttribs = [Attr {attrKey = makeQN ty, attrVal = showIRI iri}]}

setName :: String -> Element -> Element
setName s e = e {elName = nullQN {qName = s,
    qURI = Just "http://www.w3.org/2002/07/owl#"} }

setContent :: [Element] -> Element -> Element
setContent cl e = e {elContent = map Elem cl}

setText :: String -> Element -> Element
setText s e = e {elContent = [Text CData {cdVerbatim = CDataText,
    cdData = s, cdLine = Just 1}]}

setInt :: Int -> Element -> Element
setInt i e = e {elAttribs = [Attr {attrKey = makeQN "cardinality",
    attrVal = show i}]}

setDt :: Bool -> IRI -> Element -> Element
setDt b dt e = e {elAttribs = elAttribs e ++ [Attr {attrKey
    = makeQN (if b then "datatypeIRI" else "facet"), attrVal = showQU dt}]}

setLangTag :: Maybe LanguageTag -> Element -> Element
setLangTag ml e = case ml of
    Nothing -> e
    Just lt -> e {elAttribs = elAttribs e ++ [Attr {attrKey
        = setQNPrefix "xml" (makeQN "lang"), attrVal = lt}]}

mwString :: String -> Element
mwString s = setName s nullElem

mwIRI :: IRI -> Element
mwIRI iri = setIRI iri nullElem

mwNameIRI :: String -> IRI -> Element
mwNameIRI s iri = setName s $ mwIRI iri

mwText :: String -> Element
mwText s = setText s nullElem

mwSimpleIRI :: IRI -> Element
mwSimpleIRI s = setName (if isFullIri s then iriK else "AbbreviatedIRI")
    $ mwText $ showIRI s

makeElement :: String -> [Element] -> Element
makeElement s el = setContent el $ mwString s

make1 :: Bool -> String -> String -> (String -> IRI -> Element) -> IRI ->
            [([Element], Element)] -> [Element]
make1 rl hdr shdr f iri = map (\ (a, b) -> makeElement hdr
        $ a ++ (if rl then [f shdr iri, b] else [b, f shdr iri]))

make2 :: Bool -> String -> (a -> Element) -> a ->
            [([Element], Element)] -> [Element]
make2 rl hdr f expr = map (\ (x, y) -> makeElement hdr
        $ x ++ (if rl then [f expr, y] else [y, f expr]))

xmlEntity :: Entity -> Element
xmlEntity (Entity ty ent) = mwNameIRI (case ty of
    Class -> classK
    Datatype -> datatypeK
    ObjectProperty -> objectPropertyK
    DataProperty -> dataPropertyK
    AnnotationProperty -> annotationPropertyK
    NamedIndividual -> namedIndividualK) ent

xmlLiteral :: Literal -> Element
xmlLiteral (Literal lf tu) =
    let part = setName literalK $ mwText lf
    in case tu of
        Typed dt -> setDt True dt part
        Untyped lang -> setLangTag lang $ setDt True (mkQName
            "http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral")
            part

xmlIndividual :: IRI -> Element
xmlIndividual iri =
    mwNameIRI (if isAnonymous iri then anonymousIndividualK
                else namedIndividualK) iri

xmlFVPair :: (ConstrainingFacet, RestrictionValue) -> Element
xmlFVPair (cf, rv) = setDt False cf $ makeElement facetRestrictionK
    [xmlLiteral rv]

xmlObjProp :: ObjectPropertyExpression -> Element
xmlObjProp ope = case ope of
    ObjectProp op -> mwNameIRI objectPropertyK op
    ObjectInverseOf i -> makeElement objectInverseOfK [xmlObjProp i]

xmlDataRange :: DataRange -> Element
xmlDataRange dr = case dr of
    DataType dt cfl ->
        let dtelem = mwNameIRI datatypeK dt
        in if null cfl then dtelem
            else makeElement datatypeRestrictionK
            $ dtelem : map xmlFVPair cfl
    DataJunction jt drl -> makeElement (
        case jt of
            IntersectionOf -> dataIntersectionOfK
            UnionOf -> dataUnionOfK)
        $ map xmlDataRange drl
    DataComplementOf drn -> makeElement dataComplementOfK
        [xmlDataRange drn]
    DataOneOf ll -> makeElement dataOneOfK
        $ map xmlLiteral ll

xmlClassExpression :: ClassExpression -> Element
xmlClassExpression ce = case ce of
    Expression c -> mwNameIRI classK c
    ObjectJunction jt cel -> makeElement (
        case jt of
            IntersectionOf -> objectIntersectionOfK
            UnionOf -> objectUnionOfK)
        $ map xmlClassExpression cel
    ObjectComplementOf cex -> makeElement objectComplementOfK
        [xmlClassExpression cex]
    ObjectOneOf il -> makeElement objectOneOfK
        $ map xmlIndividual il
    ObjectValuesFrom qt ope cex -> makeElement (
        case qt of
            AllValuesFrom -> objectAllValuesFromK
            SomeValuesFrom -> objectSomeValuesFromK)
        [xmlObjProp ope, xmlClassExpression cex]
    ObjectHasValue ope i -> makeElement objectHasValueK
        [xmlObjProp ope, xmlIndividual i]
    ObjectHasSelf ope -> makeElement objectHasSelfK [xmlObjProp ope]
    ObjectCardinality (Cardinality ct i op mce) -> setInt i $ makeElement (
        case ct of
            MinCardinality -> objectMinCardinalityK
            MaxCardinality -> objectMaxCardinalityK
            ExactCardinality -> objectExactCardinalityK)
        $ xmlObjProp op :
        case mce of
            Nothing -> []
            Just cexp -> [xmlClassExpression cexp]
    DataValuesFrom qt dp dr -> makeElement (
        case qt of
            AllValuesFrom -> dataAllValuesFromK
            SomeValuesFrom -> dataSomeValuesFromK)
        [mwNameIRI dataPropertyK dp, xmlDataRange dr]
    DataHasValue dp l -> makeElement dataHasValueK
        [mwNameIRI dataPropertyK dp, xmlLiteral l]
    DataCardinality (Cardinality ct i dp mdr) -> setInt i $ makeElement (
        case ct of
            MinCardinality -> dataMinCardinalityK
            MaxCardinality -> dataMaxCardinalityK
            ExactCardinality -> dataExactCardinalityK)
        $ mwNameIRI dataPropertyK dp :
            case mdr of
                Nothing -> []
                Just dr -> [xmlDataRange dr]

xmlAnnotation :: Annotation -> Element
xmlAnnotation (Annotation al ap av) = makeElement annotationK
    $ map xmlAnnotation al ++ [mwNameIRI annotationPropertyK ap,
    case av of
        AnnValue iri -> mwSimpleIRI iri
        AnnValLit l -> xmlLiteral l]

xmlAnnotations :: Annotations -> [Element]
xmlAnnotations = map xmlAnnotation

xmlAL :: (a -> Element) -> AnnotatedList a -> [([Element], Element)]
xmlAL f al = let annos = map (xmlAnnotations . fst) al
                 other = map (\ (_, b) -> f b) al
             in zip annos other

xmlLFB :: Extended -> Maybe Relation -> ListFrameBit -> [Element]
xmlLFB ext mr lfb = case lfb of
    AnnotationBit al ->
        let list = xmlAL mwSimpleIRI al
            SimpleEntity (Entity _ ap) = ext
        in case fromMaybe (error "expected domain, range, subproperty") mr of
            SubPropertyOf ->
                let list2 = xmlAL (mwNameIRI annotationPropertyK) al
                in make1 True subAnnotationPropertyOfK annotationPropertyK
                         mwNameIRI ap list2
            DRRelation ADomain -> make1 True annotationPropertyDomainK
                        annotationPropertyK mwNameIRI ap list
            DRRelation ARange -> make1 True annotationPropertyRangeK
                        annotationPropertyK mwNameIRI ap list
            _ -> error "bad annotation bit"
    ExpressionBit al ->
        let list = xmlAL xmlClassExpression al in case ext of
            Misc anno -> [makeElement (case fromMaybe
                (error "expected equiv--, disjoint--, class") mr of
                    EDRelation Equivalent -> equivalentClassesK
                    EDRelation Disjoint -> disjointClassesK
                    _ -> error "bad equiv or disjoint classes bit"
                ) $ xmlAnnotations anno ++ map snd list]
            ClassEntity c -> make2 True (case fromMaybe
                (error "expected equiv--, disjoint--, sub-- class") mr of
                    SubClass -> subClassOfK
                    EDRelation Equivalent -> equivalentClassesK
                    EDRelation Disjoint -> disjointClassesK
                    _ -> error "bad equiv, disjoint, subClass bit")
                xmlClassExpression c list
            ObjectEntity op -> make2 True (case fromMaybe
                (error "expected domain, range") mr of
                    DRRelation ADomain -> objectPropertyDomainK
                    DRRelation ARange -> objectPropertyRangeK
                    _ -> "bad object domain or range bit") xmlObjProp op list
            SimpleEntity (Entity ty ent) -> case ty of
                DataProperty -> make1 True dataPropertyDomainK dataPropertyK
                        mwNameIRI ent list
                NamedIndividual -> make2 False classAssertionK
                        xmlIndividual ent list
                _ -> error "bad expression bit"
    ObjectBit al ->
        let list = xmlAL xmlObjProp al in case ext of
            Misc anno -> [makeElement (case fromMaybe
                (error "expected equiv--, disjoint-- obj prop") mr of
                    EDRelation Equivalent -> equivalentObjectPropertiesK
                    EDRelation Disjoint -> disjointObjectPropertiesK
                    _ -> error "bad object bit (equiv, disjoint)"
                ) $ xmlAnnotations anno ++ map snd list]
            ObjectEntity o -> make2 True (case fromMaybe
                (error "expected sub, Inverse, equiv, disjoint op") mr of
                    SubPropertyOf -> subObjectPropertyOfK
                    InverseOf -> inverseObjectPropertiesK
                    EDRelation Equivalent -> equivalentObjectPropertiesK
                    EDRelation Disjoint -> disjointObjectPropertiesK
                    _ -> error "bad object bit (subpropertyof, inverseof)"
                ) xmlObjProp o list
            _ -> error "bad object bit"
    DataBit al ->
        let list = xmlAL (mwNameIRI dataPropertyK) al in case ext of
            Misc anno -> [makeElement (case fromMaybe
                (error "expected equiv--, disjoint-- data prop") mr of
                    EDRelation Equivalent -> equivalentDataPropertiesK
                    EDRelation Disjoint -> disjointDataPropertiesK
                    _ -> error "bad data bit"
                ) $ xmlAnnotations anno ++ map snd list]
            SimpleEntity (Entity _ ent) -> make1 True (case fromMaybe
                    (error "expected sub, equiv or disjoint data") mr of
                        SubPropertyOf -> subDataPropertyOfK
                        EDRelation Equivalent -> equivalentDataPropertiesK
                        EDRelation Disjoint -> disjointDataPropertiesK
                        _ -> error "bad data bit"
                    ) dataPropertyK mwNameIRI ent list
            _ -> error "bad data bit"
    IndividualSameOrDifferent al ->
        let list = xmlAL xmlIndividual al in case ext of
            Misc anno -> [makeElement (case fromMaybe
                (error "expected same--, different-- individuals") mr of
                    SDRelation Same -> sameIndividualK
                    SDRelation Different -> differentIndividualsK
                    _ -> error "bad individual bit (s or d)"
                ) $ xmlAnnotations anno ++ map snd list]
            SimpleEntity (Entity _ i) -> make2 True (case fromMaybe
                (error "expected same--, different-- individuals") mr of
                    SDRelation Same -> sameIndividualK
                    SDRelation Different -> differentIndividualsK
                    _ -> error "bad individual bit (s or d)"
                ) xmlIndividual i list
            _ -> error "bad individual same or different"
    ObjectCharacteristics al ->
        let ObjectEntity op = ext
            annos = map (xmlAnnotations . fst) al
            list = zip annos (map snd al)
        in map (\ (x, y) -> makeElement (case y of
                Functional -> functionalObjectPropertyK
                InverseFunctional -> inverseFunctionalObjectPropertyK
                Reflexive -> reflexiveObjectPropertyK
                Irreflexive -> irreflexiveObjectPropertyK
                Symmetric -> symmetricObjectPropertyK
                Asymmetric -> asymmetricObjectPropertyK
                Transitive -> transitiveObjectPropertyK
                Antisymmetric -> antisymmetricObjectPropertyK
            ) $ x ++ [xmlObjProp op]) list
    DataPropRange al ->
        let SimpleEntity (Entity DataProperty dp) = ext
            list = xmlAL xmlDataRange al
        in make1 True dataPropertyRangeK dataPropertyK mwNameIRI dp list
    IndividualFacts al ->
        let SimpleEntity (Entity NamedIndividual i) = ext
            annos = map (xmlAnnotations . fst) al
            list = zip annos (map snd al)
        in map (\ (x, f) -> case f of
            ObjectPropertyFact pn op ind ->
               makeElement (case pn of
                    Positive -> objectPropertyAssertionK
                    Negative -> negativeObjectPropertyAssertionK
                ) $ x ++ [xmlObjProp op]
                        ++ map xmlIndividual [i, ind]
            DataPropertyFact pn dp lit ->
                makeElement (case pn of
                    Positive -> dataPropertyAssertionK
                    Negative -> negativeDataPropertyAssertionK
                ) $ x ++ [mwNameIRI dataPropertyK dp] ++
                        [xmlIndividual i] ++ [xmlLiteral lit]
            ) list

xmlAFB :: Extended -> Annotations -> AnnFrameBit -> [Element]
xmlAFB ext anno afb = case afb of
    AnnotationFrameBit -> case ext of
        SimpleEntity ent ->
            let Entity ty iri = ent in case ty of
                AnnotationProperty -> map (\ (Annotation as s v) ->
                    makeElement annotationAssertionK $
                        xmlAnnotations as
                            ++ [mwNameIRI annotationPropertyK iri]
                            ++ [mwSimpleIRI s, case v of
                                AnnValue avalue -> mwSimpleIRI avalue
                                AnnValLit l -> xmlLiteral l]) anno
                _ -> [makeElement declarationK
                    $ xmlAnnotations anno ++ [xmlEntity ent]]
        Misc as ->
            let [Annotation _ ap _] = anno
            in [makeElement declarationK
                $ xmlAnnotations as ++ [mwNameIRI annotationPropertyK ap]]
        _ -> error "bad ann frane bit"
    DataFunctional ->
        let SimpleEntity (Entity _ dp) = ext
        in [makeElement functionalDataPropertyK
            $ xmlAnnotations anno ++ [mwNameIRI dataPropertyK dp]]
    DatatypeBit dr ->
        let SimpleEntity (Entity _ dt) = ext
        in [makeElement datatypeDefinitionK
                $ xmlAnnotations anno ++ [mwNameIRI datatypeK dt,
                    xmlDataRange dr]]
    ClassDisjointUnion cel ->
        let ClassEntity c = ext
        in [makeElement disjointUnionK
                $ xmlAnnotations anno ++ map xmlClassExpression (c : cel)]
    ClassHasKey op dp ->
        let ClassEntity c = ext
        in [makeElement hasKeyK
                $ xmlAnnotations anno ++ [xmlClassExpression c]
                    ++ map xmlObjProp op ++ map (mwNameIRI dataPropertyK) dp]
    ObjectSubPropertyChain opl ->
        let ObjectEntity op = ext
            xmlop = map xmlObjProp opl
        in [makeElement subObjectPropertyOfK
                $ xmlAnnotations anno ++
                    [makeElement objectPropertyChainK xmlop, xmlObjProp op]]

xmlFrameBit :: Extended -> FrameBit -> [Element]
xmlFrameBit ext fb = case fb of
    ListFrameBit mr lfb -> xmlLFB ext mr lfb
    AnnFrameBit anno afb -> xmlAFB ext anno afb

xmlAxioms :: Axiom -> [Element]
xmlAxioms (PlainAxiom ext fb) = xmlFrameBit ext fb

xmlFrames :: Frame -> [Element]
xmlFrames (Frame ext fbl) = concatMap (xmlFrameBit ext) fbl

xmlImport :: ImportIRI -> Element
xmlImport i = setName importK $ mwText $ showIRI i

setPref :: String -> Element -> Element
setPref s e = e {elAttribs = Attr {attrKey = makeQN "name"
    , attrVal = s} : elAttribs e}

set1Map :: (String, String) -> Element
set1Map (s, iri) = setPref s $ mwIRI $ setFull $ splitIRI "" $ mkQName iri

xmlPrefixes :: PrefixMap -> [Element]
xmlPrefixes pm = map (setName prefixK . set1Map) $ Map.toList pm

setXMLNS :: Element -> Element
setXMLNS e = e {elAttribs = Attr {attrKey = makeQN "xmlns", attrVal =
        "http://www.w3.org/2002/07/owl#"} : elAttribs e}

setOntIRI :: OntologyIRI -> Element -> Element
setOntIRI iri e =
    if elem iri [nullQName, dummyQName] then e 
     else e {elAttribs = Attr {attrKey = makeQN "ontologyIRI",
        attrVal = showQU iri} : elAttribs e}

setBase :: String -> Element -> Element
setBase s e = e {elAttribs = Attr {attrKey = nullQN {qName = "base",
        qPrefix = Just "xml"}, attrVal = s} : elAttribs e}

xmlOntologyDoc :: OntologyDocument -> Element
xmlOntologyDoc od =
    let ont = ontology od
        pd = prefixDeclaration od
        emptyPref = fromMaybe (showIRI dummyQName) $ Map.lookup "" pd
    in setBase emptyPref $ setXMLNS $ setOntIRI (name ont)
        $ makeElement "Ontology" $ xmlPrefixes pd
            ++ map xmlImport (imports ont)
            ++ concatMap xmlFrames (ontFrames ont)
            ++ concatMap xmlAnnotations (ann ont)

mkODoc :: Sign -> [Named Axiom] -> String
mkODoc s na = ppTopElement $ xmlOntologyDoc $ emptyOntologyDoc
    {
      ontology = emptyOntologyD
        {
        ontFrames = map (axToFrame . sentence) na
        },
      prefixDeclaration = prefixMap s
    }