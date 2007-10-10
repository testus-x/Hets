{- |
Module      :  $Id$
Description :  Abstract syntax fo CspCASL
Copyright   :  (c) Markus Roggenbach and Till Mossakowski and Uni Bremen 2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  a.m.gimblett@swan.ac.uk
Stability   :  provisional
Portability :  portable

Abstract syntax of CSP-CASL processes.

-}
module CspCASL.AS_CspCASL where

import CASL.AS_Basic_CASL (VAR)
import CspCASL.AS_CspCASL_Process (EVENT_SET, PROCESS, PROCESS_NAME)

data CspBasicSpec = CspBasicSpec
    { channels :: [CHANNEL]
    , proc_decls :: [PROC_DECL]
    , processes :: [PROC_EQ]
    } deriving Show

data CHANNEL = Channel
    { channelNames :: [VAR],
      channelSort :: EVENT_SET
    } deriving Show

--data CHANNEL_DECL = Channel_items [CHANNEL_ITEM]
--                   deriving Show
--
--data CHANNEL_ITEM = Channel_decl [CHANNEL_NAME] SORT
--                   deriving Show
--
--type CHANNEL_NAME = Id

data PROC_DECL = ProcDecl PROCESS_NAME [EVENT_SET] EVENT_SET
    deriving Show

data PROC_EQ = ProcEq PARM_PROCNAME PROCESS
    deriving Show

data PARM_PROCNAME = ParmProcname PROCESS_NAME [VAR]
    deriving Show

