 --------------------------------------------------------------------------------
-- | Implementation of Hakyll commands: build, preview...
{-# LANGUAGE CPP #-}
module Hakyll.Commands
    ( build
    , check
    , clean
    , preview
    , rebuild
    , server
    , deploy
    , watch 
    ) where


--------------------------------------------------------------------------------
import           System.Exit                (exitWith, ExitCode)
import           Control.Applicative
import           Control.Concurrent

--------------------------------------------------------------------------------
import qualified Hakyll.Check               as Check
import           Hakyll.Core.Configuration
import           Hakyll.Core.Logger         (Verbosity)
import           Hakyll.Core.Rules
import           Hakyll.Core.Rules.Internal
import           Hakyll.Core.Runtime
import           Hakyll.Core.Util.File

--------------------------------------------------------------------------------
#ifdef WATCH_SERVER
import           Hakyll.Preview.Poll (watchUpdates)
#endif

#ifdef PREVIEW_SERVER
import           Hakyll.Preview.Server
#endif


--------------------------------------------------------------------------------
-- | Build the site
build :: Configuration -> Verbosity -> Rules a -> IO ExitCode
build conf verbosity rules = fst <$> run conf verbosity rules

--------------------------------------------------------------------------------
-- | Run the checker and exit
check :: Configuration -> Verbosity -> Check.Check -> IO ()
check config verbosity check' = Check.check config verbosity check' >>= exitWith


--------------------------------------------------------------------------------
-- | Remove the output directories
clean :: Configuration -> IO ()
clean conf = do
    remove $ destinationDirectory conf
    remove $ storeDirectory conf
    remove $ tmpDirectory conf
  where
    remove dir = do
        putStrLn $ "Removing " ++ dir ++ "..."
        removeDirectory dir


--------------------------------------------------------------------------------
-- | Preview the site
preview :: Configuration -> Verbosity -> Rules a -> Int -> IO ()
#ifdef PREVIEW_SERVER
preview conf verbosity rules port  = do
    deprecatedMessage
    watch conf verbosity port True rules
  where
    deprecatedMessage = mapM_ putStrLn [ "The preview command has been deprecated."
                                       , "Use the watch command for recompilation and serving."
                                       ]
#else
preview _ _ _ _ = previewServerDisabled
#endif


--------------------------------------------------------------------------------
-- | Watch and recompile for changes

watch :: Configuration -> Verbosity -> Int -> Bool -> Rules a -> IO ()
#ifdef WATCH_SERVER
watch conf verbosity port runServer rules = do
    watchUpdates conf update
    _ <- forkIO (server')
    loop
  where
    update = do
        (_, ruleSet) <- run conf verbosity rules
        return $ rulesPattern ruleSet

    loop = threadDelay 100000 >> loop

    server' = if runServer then server conf port else return ()
#else
watch _ _ _ _ _ = watchServerDisabled
#endif

--------------------------------------------------------------------------------
-- | Rebuild the site
rebuild :: Configuration -> Verbosity -> Rules a -> IO ExitCode
rebuild conf verbosity rules =
    clean conf >> build conf verbosity rules

--------------------------------------------------------------------------------
-- | Start a server
server :: Configuration -> Int -> IO ()
#ifdef PREVIEW_SERVER
server conf port = do
    let destination = destinationDirectory conf
    staticServer destination preServeHook port
  where
    preServeHook _ = return ()
#else
server _ _ = previewServerDisabled
#endif


--------------------------------------------------------------------------------
-- | Upload the site
deploy :: Configuration -> IO ExitCode
deploy conf = deploySite conf conf


--------------------------------------------------------------------------------
-- | Print a warning message about the preview serving not being enabled
#ifndef PREVIEW_SERVER
previewServerDisabled :: IO ()
previewServerDisabled =
    mapM_ putStrLn
        [ "PREVIEW SERVER"
        , ""
        , "The preview server is not enabled in the version of Hakyll. To"
        , "enable it, set the flag to True and recompile Hakyll."
        , "Alternatively, use an external tool to serve your site directory."
        ]
#endif

#ifndef WATCH_SERVER
watchServerDisabled :: IO ()
watchServerDisabled =
    mapM_ putStrLn
      [ "WATCH SERVER"
      , ""
      , "The watch server is not enabled in the version of Hakyll. To"
      , "enable it, set the flag to True and recompile Hakyll."
      , "Alternatively, use an external tool to serve your site directory."
      ]
#endif

