{- |
Module      :$Header$
Description : Internal state of the CMDL interface
Copyright   : uni-bremen and DFKI
Licence     : similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  : r.pascanu@iu-bremen.de
Stability   : provisional
Portability : portable

PGIP.CMDLState describes the internal state of the CMDL 
interface and provides basic functions related to the 
internal state.
-} 


module PGIP.CMDLState
       ( CMDLProofAbstractState(..)
       , initCMDLProofAbstractState
       , CMDLProveState(..)
       , CMDLDevGraphState(..)
       , CMDLState(..)
       , emptyCMDLState
       , getAllNodes
       , getAllGoalNodes
       , getAllEdges
       , getAllGoalEdges
       , CommandTypes(..)
       ) where 

import PGIP.CMDLUtils

import Data.Graph.Inductive.Graph

import Static.DevGraph

import Logic.Grothendieck
import Logic.Logic

import Syntax.AS_Library

import Proofs.AbstractState

-- AbstractState depends on lid and sentence, and in order
-- not to change to much CMDLProveState requires some 
-- independent type
-- also CMDL interface requires to keep track of the node
-- number
data CMDLProofAbstractState = forall lid1 sublogics1 
         basic_spec1 sentence1 symb_items1 symb_map_items1
         sign1 morphism1 symbol1 raw_symbol1 proof_tree1 .
         Logic lid1 sublogics1 basic_spec1 sentence1 
         symb_items1 symb_map_items1 sign1 morphism1 
         symbol1 raw_symbol1 proof_tree1 =>
     Element (ProofState lid1 sentence1) Int


-- | Constructor for CMDLProofGUIState datatype
initCMDLProofAbstractState:: (Logic lid1 sublogics1
         basic_spec1 sentence1 symb_items1 symb_map_items1 
         sign1 morphism1 symbol1 raw_symbol1 proof_tree1) =>
         ProofState lid1 sentence1 -> Int 
         -> CMDLProofAbstractState
initCMDLProofAbstractState ps nb
 = Element ps nb

-- | During the prove mode, the CMDL interface will use the 
-- informations stored in the Prove state, which consists of 
-- the list of elements selected,  the list of comorphism 
-- applied to the list (where the first in the list is the 
-- last applied comorphism, the selected prover and the 
-- script.
data CMDLProveState = 
  CMDLProveState {
    -- | selected nodes as elements (only the theory and the
    -- node number from where the theory was taken)
    elements     :: [CMDLProofAbstractState] ,
    -- | list of all comorphism applied to the list (the 
    -- first in the list is the last applied). 
    uComorphisms :: [AnyComorphism],
    -- | Selected prover
    prover      :: Maybe G_prover,
    -- | Script to be used when proving
    script      :: String
    }


-- | During the development graph mode, the CMDL interface 
-- will use the information stored in CMDLDevGraphState which 
-- consist of the library loaded and a list of all nodes 
-- and edges.
data CMDLDevGraphState = CMDLDevGraphState {
    -- | the LIB_NAME of the loaded library
    ln               :: LIB_NAME,
    -- | the LibEnv of the loaded library
    libEnv           :: LibEnv,
    -- | List of all nodes from the development graph. 
    -- List might be out of date, please use 
    -- allNodesUpToDate to check
    allNodes         :: [LNode DGNodeLab],
    -- | Indicator if the list of all nodes is up to date 
    -- or if it needs 
    -- to be recomputed
    allNodesUpToDate :: Bool,
    -- | List of all edges from the development graph. List 
    -- might be out of date, please use allEdgesUpToDate to 
    -- check
    allEdges         :: [LEdge DGLinkLab],
    -- | Indicator if the list of all edges is up to date or 
    -- if it needs to be recomputed
    allEdgesUpToDate :: Bool
    }

 
-- | CMDLState contains all information the CMDL interface
-- might use at any time.
data CMDLState = CMDLState {
  -- | development  graph mode information
  devGraphState   :: Maybe CMDLDevGraphState,
  -- | prove mode information
  proveState      :: Maybe CMDLProveState,
  -- | promter of the interface
  prompter        :: String,
  -- | error String, any error occurance has to fill
  -- this String with an error message
  errorMsg        :: String
 }



-- | Creates an initial state of the CMDL interface
emptyCMDLState :: CMDLState
emptyCMDLState =
    CMDLState {
        devGraphState = Nothing,
        proveState    = Nothing,
        prompter      = "> ",
        errorMsg      = ""
        }

-- | Returns the list of all nodes, if it is not up to date
-- the function recomputes the list
getAllNodes :: CMDLDevGraphState -> [LNode DGNodeLab]
getAllNodes state
 = case allNodesUpToDate state of
    -- nodes are up to date
    True -> allNodes state
    -- nodes are not up to date
    False -> labNodesDG $ lookupDGraph (ln state)
                             (libEnv state)


-- | Returns the list of all nodes that are goals, 
-- taking care of the up to date status
getAllGoalNodes :: CMDLDevGraphState -> [LNode DGNodeLab]
getAllGoalNodes state
 = filter nodeContainsGoals $ getAllNodes state

-- | Returns the list of all edges, if it is not up to date
-- the funcrion recomputes the list
getAllEdges :: CMDLDevGraphState -> [LEdge DGLinkLab]
getAllEdges state
 = case allEdgesUpToDate state of
    -- edges are up to date
    True -> allEdges state
    -- edges are not up to date
    False -> labEdgesDG $ lookupDGraph (ln state)
                            (libEnv state)

-- | Returns the list of all goal edges taking care of the
-- up to date status
getAllGoalEdges :: CMDLDevGraphState -> [LEdge DGLinkLab]
getAllGoalEdges state
 = filter edgeContainsGoals $ getAllEdges state


-- | Datatype describing the types of commands according 
-- to what they expect as input
data CommandTypes = 
-- requires nodes 
   ReqNodes 
-- requires edges
 | ReqEdges
-- requires nodes and edges
 | ReqNodesAndEdges
-- requires provers
 | ReqProvers
-- requires comorphisms
 | ReqComorphism
-- requires a file (*.casl)
 | ReqFile
-- require goal nodes
 | ReqGNodes
-- require goal edges
 | ReqGEdges
-- require goal noes and edges
 | ReqGNodesAndGEdges
-- not recognized 
 | ReqUnknown
