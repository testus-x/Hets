{-# LANGUAGE DeriveDataTypeable #-}
{- |
Module      :  ./OWL2/Profiles.hs
Copyright   :  (c) Felix Gabriel Mance
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.mance@jacobs-university.de
Stability   :  provisional
Portability :  portable

OWL2 Profiles (EL, QL and RL)

References  :  <http://www.w3.org/TR/owl2-profiles/>
-}

module OWL2.Profiles where

import qualified OWL2.AS as AS
import OWL2.MS

import Data.Data
import Data.Maybe

data Profiles = Profiles
    { el :: Bool
    , ql :: Bool
    , rl :: Bool
    } deriving (Show, Eq, Ord, Typeable, Data)

allProfiles :: [[Profiles]]
allProfiles =
  [[qlrlProfile], [elrlProfile], [elqlProfile]]

bottomProfile :: Profiles
bottomProfile = Profiles False False False

topProfile :: Profiles
topProfile = Profiles True True True

elProfile :: Profiles
elProfile = Profiles True False False

qlProfile :: Profiles
qlProfile = Profiles False True False

rlProfile :: Profiles
rlProfile = Profiles False False True

elqlProfile :: Profiles
elqlProfile = Profiles True True False

elrlProfile :: Profiles
elrlProfile = Profiles True False True

qlrlProfile :: Profiles
qlrlProfile = Profiles False True True

printProfile :: Profiles -> String
printProfile p@(Profiles e q r) = case p of
    (Profiles False False False) -> "NP"
    _ -> (if e then "EL" else "")
            ++ (if q then "QL" else "")
            ++ (if r then "RL" else "")

andProfileList :: [Profiles] -> Profiles
andProfileList pl = topProfile
    { el = all el pl
    , ql = all ql pl
    , rl = all rl pl }

andList :: (a -> Profiles) -> [a] -> Profiles
andList f cel = andProfileList (map f cel)

minimalCovering :: Profiles -> [Profiles] -> Profiles
minimalCovering c pl = andProfileList [c, andProfileList pl]

dataType :: AS.Datatype -> Profiles
dataType _ = topProfile -- needs to be implemented, of course

literal :: AS.Literal -> Profiles
literal _ = topProfile -- needs to be implemented

individual :: AS.Individual -> Profiles
individual i = if AS.isAnonymous i then rlProfile else topProfile

objProp :: AS.ObjectPropertyExpression -> Profiles
objProp ope = case ope of
    AS.ObjectInverseOf _ -> qlrlProfile
    _ -> topProfile

dataRange :: AS.DataRange -> Profiles
dataRange dr = case dr of
    AS.DataType dt cfl ->
        if null cfl then dataType dt
         else bottomProfile
    AS.DataJunction AS.IntersectionOf drl -> andProfileList $ map dataRange drl
    AS.DataOneOf ll -> bottomProfile {
                        el = el (andList literal ll) && length ll == 1
                    }
    _ -> bottomProfile

subClass :: AS.ClassExpression -> Profiles
subClass cex = case cex of
    AS.Expression c -> if AS.isThing c then elqlProfile else topProfile
    AS.ObjectJunction jt cel -> minimalCovering (case jt of
        AS.IntersectionOf -> elrlProfile
        AS.UnionOf -> rlProfile) $ map subClass cel
    AS.ObjectOneOf il -> bottomProfile {
                    el = el (andList individual il) && length il == 1,
                    rl = ql $ andList individual il
                }
    AS.ObjectValuesFrom AS.SomeValuesFrom ope ce -> andProfileList [objProp ope,
        case ce of
            AS.Expression c -> if AS.isThing c then topProfile
                             else elrlProfile
            _ -> minimalCovering elrlProfile [subClass ce]]
    AS.ObjectHasValue ope i -> minimalCovering elrlProfile
       [objProp ope, individual i]
    AS.ObjectHasSelf ope -> minimalCovering elProfile [objProp ope]
    AS.DataValuesFrom AS.SomeValuesFrom _ dr -> dataRange dr
    AS.DataHasValue _ l -> literal l
    _ -> bottomProfile

superClass :: AS.ClassExpression -> Profiles
superClass cex = case cex of
    AS.Expression c -> if AS.isThing c then elqlProfile else topProfile
    AS.ObjectJunction AS.IntersectionOf cel -> andList superClass cel
    AS.ObjectComplementOf ce -> minimalCovering qlrlProfile [subClass ce]
    AS.ObjectOneOf il -> bottomProfile {
                    el = el (andList individual il) && length il == 1,
                    rl = ql $ andList individual il
                }
    AS.ObjectValuesFrom qt ope ce -> case qt of
        AS.SomeValuesFrom -> andProfileList [objProp ope, case ce of
            AS.Expression _ -> elqlProfile
            _ -> elProfile]
        AS.AllValuesFrom -> andProfileList [superClass ce, rlProfile]
    AS.ObjectHasValue ope i -> andProfileList [elrlProfile, objProp ope,
        individual i]
    AS.ObjectHasSelf ope -> andProfileList [elProfile, objProp ope]
    AS.ObjectCardinality (AS.Cardinality AS.MaxCardinality i _ mce) ->
        if elem i [0, 1] then andProfileList [rlProfile, case mce of
            Nothing -> topProfile
            Just ce -> case ce of
                AS.Expression _ -> topProfile
                _ -> subClass ce]
         else bottomProfile
    AS.DataValuesFrom qt _ dr -> andProfileList [dataRange dr, case qt of
        AS.SomeValuesFrom -> elqlProfile
        AS.AllValuesFrom -> rlProfile]
    AS.DataHasValue _ l -> andProfileList [elrlProfile, literal l]
    AS.DataCardinality (AS.Cardinality AS.MaxCardinality i _ mdr) ->
        if elem i [0, 1] then andProfileList [rlProfile, case mdr of
            Nothing -> topProfile
            Just dr -> dataRange dr]
         else bottomProfile
    _ -> bottomProfile

equivClassRL :: AS.ClassExpression -> Bool
equivClassRL cex = case cex of
    AS.Expression c -> (not . AS.isThing) c
    AS.ObjectJunction AS.IntersectionOf cel -> all equivClassRL cel
    AS.ObjectHasValue _ i -> rl $ individual i
    AS.DataHasValue _ l -> rl $ literal l
    _ -> False

annotation :: AS.Annotation -> Profiles
annotation (AS.Annotation as _ av) = andProfileList [annotations as, case av of
    AS.AnnValLit l -> literal l
    _ -> topProfile]

annotations :: Annotations -> Profiles
annotations ans = andProfileList $ map annotation ans

assertionQL :: AS.ClassExpression -> Bool
assertionQL ce = case ce of
    AS.Expression _ -> True
    _ -> False

char :: [AS.Character] -> [AS.Character] -> Bool
char charList ls = all (`elem` ls) charList

fact :: Fact -> Profiles
fact f = case f of
    ObjectPropertyFact pn ope i -> andProfileList [objProp ope, individual i,
        case pn of
            AS.Positive -> topProfile
            AS.Negative -> elrlProfile]
    DataPropertyFact pn _ l -> andProfileList [literal l,
        case pn of
            AS.Positive -> topProfile
            AS.Negative -> elrlProfile]

lFB :: Extended -> Maybe AS.Relation -> ListFrameBit -> Profiles
lFB ext mr lfb = case lfb of
    AnnotationBit anl -> annotations $ concatMap fst anl
    ExpressionBit anl ->
        let ans = annotations $ concatMap fst anl
            cel = map snd anl
            r = fromMaybe (error "relation needed") mr
        in case ext of
            Misc anno -> andProfileList [ans, annotations anno,
                bottomProfile {
                    el = el $ andList subClass cel,
                    ql = ql $ andList subClass cel,
                    rl = all equivClassRL cel
                }]
            ClassEntity c -> case r of
                AS.SubClass -> andProfileList [ans, subClass c,
                    andList superClass cel]
                _ -> andProfileList [ans, bottomProfile {
                    el = el $ andList subClass $ c : cel,
                    ql = ql $ andList subClass $ c : cel,
                    rl = all equivClassRL $ c : cel
                }]
            ObjectEntity op -> andProfileList [ans, objProp op,
                andList superClass cel]
            SimpleEntity (AS.Entity _ ty ent) -> case ty of
                AS.DataProperty -> andProfileList [ans, andList superClass cel]
                AS.NamedIndividual -> andProfileList [ans, individual ent,
                    bottomProfile {
                        el = el $ andList superClass cel,
                        ql = all assertionQL cel,
                        rl = rl $ andList superClass cel
                    }]
                _ -> error "invalid expression bit"
    ObjectBit anl ->
        let ans = annotations $ concatMap fst anl
            opl = andList objProp $ map snd anl
            r = fromMaybe (error "relation needed") mr
        in case ext of
            Misc anno -> andProfileList [ans, annotations anno, opl, case r of
                AS.EDRelation AS.Equivalent -> topProfile
                _ -> qlrlProfile]
            ObjectEntity op -> andProfileList [ans, opl, objProp op, case r of
                AS.SubPropertyOf -> topProfile
                AS.EDRelation AS.Equivalent -> topProfile
                _ -> qlrlProfile]
            _ -> error "invalit object bit"
    DataBit anl ->
        let ans = annotations $ concatMap fst anl
            r = fromMaybe (error "relation needed") mr
        in case ext of
            Misc anno -> andProfileList [ans, annotations anno, case r of
                AS.EDRelation AS.Equivalent -> topProfile
                _ -> qlrlProfile]
            _ -> andProfileList [ans, case r of
                    AS.SubPropertyOf -> topProfile
                    AS.EDRelation AS.Equivalent -> topProfile
                    _ -> qlrlProfile]
    IndividualSameOrDifferent anl ->
        let ans = annotations $ concatMap fst anl
            r = fromMaybe (error "relation needed") mr
            i = andList individual $ map snd anl
        in case ext of
            Misc anno -> andProfileList [ans, annotations anno, i, case r of
                AS.SDRelation AS.Different -> topProfile
                _ -> elrlProfile]
            SimpleEntity (AS.Entity _ _ ind) -> andProfileList [ans, individual ind,
                i, case r of
                    AS.SDRelation AS.Different -> topProfile
                    _ -> elrlProfile]
            _ -> error "bad individual bit"
    ObjectCharacteristics anl ->
        let ans = annotations $ concatMap fst anl
            cl = map snd anl
        in case ext of
            ObjectEntity op -> andProfileList [ans, objProp op,
                    bottomProfile {
                        el = char cl [AS.Reflexive, AS.Transitive],
                        ql = char cl [AS.Reflexive, AS.Symmetric, AS.Asymmetric],
                        rl = char cl [AS.Functional, AS.InverseFunctional,
                                AS.Irreflexive, AS.Symmetric, AS.Asymmetric, AS.Transitive]
                    }]
            _ -> error "object entity needed"
    DataPropRange anl ->
        let ans = annotations $ concatMap fst anl
            dr = andList dataRange $ map snd anl
        in andProfileList [ans, dr]
    IndividualFacts anl ->
        let ans = annotations $ concatMap fst anl
            facts = andList fact $ map snd anl
        in case ext of
            SimpleEntity (AS.Entity _ _ i) ->
                andProfileList [ans, facts, individual i]
            _ -> error "bad fact bit"

aFB :: Extended -> Annotations -> AnnFrameBit -> Profiles
aFB ext anno afb =
    let ans = annotations anno
    in case afb of
        AnnotationFrameBit _ -> ans
        DataFunctional -> andProfileList [ans, elrlProfile]
        DatatypeBit dr -> case ext of
            SimpleEntity (AS.Entity _ _ dt) -> andProfileList
                [ans, dataType dt, dataRange dr]
            _ -> error "bad datatype bit"
        ClassDisjointUnion _ -> bottomProfile
        ClassHasKey opl _ -> case ext of
            ClassEntity ce -> minimalCovering elrlProfile
                [ans, andList objProp opl, subClass ce]
            _ -> error "bad has key"
        ObjectSubPropertyChain opl -> case ext of
            ObjectEntity op -> minimalCovering elrlProfile
                [ans, andList objProp $ op : opl]
            _ -> error "bad sub property chain"

fB :: Extended -> FrameBit -> Profiles
fB ext fb = case fb of
    ListFrameBit mr lfb -> lFB ext mr lfb
    AnnFrameBit anno afb -> aFB ext anno afb

axiom :: Axiom -> Profiles
axiom (PlainAxiom ext fb) = fB ext fb

frame :: Frame -> Profiles
frame (Frame ext fbl) = andList (fB ext) fbl

ontologyP :: Ontology -> Profiles
ontologyP ont =
    let anns = ann ont
        fr = ontFrames ont
    in andProfileList [andList frame fr, andList annotations anns]

ontologyProfiles :: OntologyDocument -> Profiles
ontologyProfiles odoc = ontologyP $ ontology odoc
