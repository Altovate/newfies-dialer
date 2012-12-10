--
-- Newfies-Dialer License
-- http://www.newfies-dialer.org
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (C) 2011-2012 Star2Billing S.L.
--
-- The Initial Developer of the Original Code is
-- Arezqui Belaid <info@star2billing.com>
--


package.path = package.path .. ";/home/areski/public_html/django/MyProjects/newfies-dialer/lua/?.lua";
package.path = package.path .. ";/home/areski/public_html/django/MyProjects/newfies-dialer/lua/libs/?.lua";

require "luasql.postgres"
require "dumper"
require "logging.file"
require "database"
require "fsm_callflow"

-- Set if the environment is FreeSWITCH
fs_env = true
debug_mode = false

if not fs_env then
    require "session"
    session = Session()
end


local callflow = FSMCall(session, debug_mode)
local db = Database(debug_mode)

survey_id = 6
db:connect()
db:load_all(survey_id)
db:disconnect()
--print(DataDumper(db.list_audio))

--error(_die)

DIRAUDIO = '/home/areski/public_html/django/MyProjects/newfies-dialer/newfies/usermedia/tts/'
AUDIO_WELCOME = DIRAUDIO..'script_9805d01afeec350f36ff3fd908f0cbd5.wav'
AUDIO_ENTERAGE = DIRAUDIO..'script_4ee73b76b5b4c5d596ed1cb3257861f0.wav'
AUDIO_PRESSDIGIT = DIRAUDIO..'script_610e09c761c4b592aaa954259ce4ce1d.wav'

local logger = logging.file("logs_%s.log", "%Y-%m-%d")

-- This function simply tells us what function are available in Session
--   It just prints a list of all functions.  We may be able to find functions
--   that have not yet been documented but are useful.  I did :)
function printSessionFunctions( session )

   metatbl = getmetatable(session)
   if not metatbl then return nil end

   local f=metatbl['.fn'] -- gets the functions table
   if not f then return nil end

   print("\n***Session Functions***\n")
   for k,v in pairs(f) do print(k,v) end
   print("\n\n")

end
-- new_session = freeswitch.Session() -- create a blank session
-- printSessionFunctions(new_session)

function debug(level, message)
    -- level : INFO, NOTICE, ...
    if fs_env then
        freeswitch.consoleLog(level, message)
    else
        print(message)
    end
    logger:setLevel(logging.DEBUG)
    logger:info("logging.file test")

end


function myHangupHook(s, status, arg)
    debug("NOTICE", "myHangupHook: status -> " .. status .. "\n")
    local obCause = session:hangupCause()
    debug("INFO", "session:hangupCause() = " .. obCause )
    -- local xmlcdr = session:getXMLCDR()
    -- debug("info", "session:getXMLCDR() = " .. xmlcdr )
    error()
end


if session:ready() then

    session:answer()
    session:setHangupHook("myHangupHook")

    callflow:init()
    callflow:start_call()

    -- Play Message
    -- session:streamFile(AUDIO_WELCOME);

    -- digits = session:playAndGetDigits (
    --       min_digits, max_digits, max_attempts, timeout, terminators,
    --       prompt_audio_files, input_error_audio_files,
    --       digit_regex, variable_name, digit_timeout,
    --       transfer_on_failure)

    -- Multi Choice
    press_digit = session:playAndGetDigits(1, 1, 3, 4000, '#', AUDIO_PRESSDIGIT, '', '\\d+|#')
    debug("info", "press digit = " .. press_digit )

    -- Capture Digits
    entered_age = session:playAndGetDigits(1, 6, 3, 4000, '#', AUDIO_ENTERAGE, '', '\\d+|#')
    debug("info", "entered_age = " .. entered_age )

    -- Recording
    recording_dir = '/tmp/'
    filename = 'myfile.wav'
    recording_filename = string.format('%s%s', recording_dir, filename)

    if session:ready() then
        -- syntax is session:recordFile(file_name, max_len_secs, silence_threshold, silence_secs)
        max_len_secs = 30
        silence_threshold = 30
        silence_secs = 5
        test = session:recordFile(recording_filename, max_len_secs, silence_threshold, silence_secs)
    end


    -- max_attempts = 1
    -- audiofile = '/usr/local/freeswitch/sounds/en/us/callie/voicemail/8000/vm-enter_new_pin.wav'

    -- while max_attempts > 0 do
    --     -- expect 1-6 digits, max_tries=3, timeout=4s, terminator=#
    --     agent_id = session:playAndGetDigits(1, 6, 3, 4000, '#', audiofile, '', '\\d+|#')

    --     -- did we actually get an agent_id?
    --     if agent_id == "" then
    --         session:sayPhrase("voicemail_goodbye")
    --         session:hangup()
    --     end

    --     max_attempts = max_attempts - 1
    -- end

    session:sayPhrase("welcome")

    -- End call
    callflow:end_call()

else
    -- This means the call was not answered ... Check for the reason
    local obCause = session:hangupCause()
    debug("info", "obSession:hangupCause() = " .. obCause )

    if ( obCause == "USER_BUSY" ) then              -- SIP 486
       -- For BUSY you may reschedule the call for later
    elseif ( obCause == "NO_ANSWER" ) then
       -- Call them back in an hour
    elseif ( obCause == "ORIGINATOR_CANCEL" ) then   -- SIP 487
       -- May need to check for network congestion or problems
    else
       -- Log these issues
    end
end

error(_die);
