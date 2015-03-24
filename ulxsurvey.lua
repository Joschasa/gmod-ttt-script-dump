Survey = Survey or {}
function Survey:FormatTime(t)
    if t < 60 then
        if t == 1 then return "one second" else return t.." seconds" end
    elseif t < 3600 then
        if math.Round(t/60) == 1 then return "one minute" else return math.Round(t/60).." minutes" end
    elseif t < 24*3600 then
        if math.Round(t/3600) == 1 then return "one hour" else return math.Round(t/3600).." hours" end
    elseif t < 24*3600* 7 then
        if math.Round(t/(24*3600)) == 1 then return "one day" else return math.Round(t/(24*3600)).." days" end
    elseif t < 24*3600*30 then
        if math.Round(t/(24*3600*7)) == 1 then return "one week" else return math.Round(t/(24*3600*7)).." weeks" end
    else
        if math.Round(t/(24*3600*30)) == 1 then return "one month" else return math.Round(t/(24*3600*30)).." months" end
    end
end
function Survey:WordWrap(str, limit, indent, indent1)
    indent = indent or ""
    indent1 = indent1 or indent
    limit = limit or 72
    local here = 1-#indent1
    return indent1..str:gsub("(%s+)()(%S+)()",
    function(sp, st, word, fi)
        if fi-here > limit then
            here = st - #indent
            return "\n"..indent..word
        end
    end)
end

if SERVER then
    util.AddNetworkString("SURVEY_PendingQuestion")
    util.AddNetworkString("SURVEY_Answer")
    util.AddNetworkString("SURVEY_GetPendingQuestion")
    util.AddNetworkString("SURVEY_GetQuestions")
    util.AddNetworkString("SURVEY_GetAnswers")
    -- Create tables
    if not sql.TableExists("survey_questions") then
        sql.Query([[CREATE TABLE survey_questions (
        adminname     varchar(255) NOT NULL,
        adminrank     varchar(255) NOT NULL,
        adminsteamid  varchar(255) NOT NULL,
        question      tinytext     NOT NULL,
        questiontype  tinytext     NOT NULL,
        questiongroup tinytext     NOT NULL,
        active        INTEGER      NOT NULL,
        date          INTEGER      NOT NULL
        ) ]])
    end
    if not sql.TableExists("survey_answers") then
        sql.Query([[CREATE TABLE survey_answers (
        questionid   INTEGER      NOT NULL,
        username     varchar(255) NOT NULL,
        userrank     varchar(255) NOT NULL,
        usersteamid  varchar(255) NOT NULL,
        answer       tinytext     NOT NULL,
        date         INTEGER      NOT NULL
        ) ]])
    end

    function Survey:AskQuestion(admin, qtype, qgroup, question)
        local adminname, adminrank, adminsteamid
        if IsValid(admin) and type(admin) == "Player" then
            adminname = sql.SQLStr(admin:Nick(), true)
            adminrank = sql.SQLStr(admin:GetUserGroup(), true)
            adminsteamid = admin:SteamID()
        else
            adminname = "Console"
            adminrank = "superadmin"
            adminsteamid = "Console"
        end
        if qtype ~= "accept" and qtype ~= "yesno" and qtype ~= "comment" then
            -- not supported type of question
            admin:ChatPrint("Type of question is not supported!")
            return
        end
        -- qgroup is checked by ulx
        local result = sql.Query("INSERT INTO survey_questions (adminname, adminrank, adminsteamid, question, questiontype, questiongroup, active, date) VALUES ('"..adminname.."', '"..adminrank.."', '"..adminsteamid.."', "..sql.SQLStr(question)..", '"..qtype.."', '"..qgroup.."', 1, "..os.time()..")")
        if result == false then
            admin:ChatPrint("SQL-Fehler: "..sql.LastError())
        else
            ulx.fancyLogAdmin(admin, true, "#A started a new survey: #s", question)
        end
    end

    function Survey:GetQuestion(admin, qid)
        -- qid = tonumber(qid) -- ULX seems to care for their functions...garry!
        if(qid > 0) then
            -- get answers for a specific question...
            local question = sql.Query("SELECT rowid,* FROM survey_questions WHERE rowid == "..qid..";")
            if not question then admin:ChatPrint("Question not found."); return end
            local answers = sql.Query("SELECT rowid,* FROM survey_answers WHERE questionid == "..qid..";")
            net.Start("SURVEY_GetAnswers")
            net.WriteTable(question)
            net.WriteTable(answers)
            net.Send(admin)
        else
            -- List all questions
            local questions = sql.Query("SELECT rowid,* FROM survey_questions;")
            questions = questions or {}
            net.Start("SURVEY_GetQuestions")
            net.WriteTable(questions)
            net.Send(admin)
        end
    end

    function Survey:ToggleQuestion(admin, qid, state)
        if state and (state < -1 or state > 1) then admin:ChatPrint("State can only be 0 or 1!"); return end
        -- Check, if question exists
        local result = sql.QueryRow("SELECT question, active FROM survey_questions WHERE rowid == "..qid..";")
        if not result then admin:ChatPrint("Question not found."); return end
        local currentstate = tonumber(result.active)
        local newstate = 1 - currentstate
        if state >= 0 then newstate = state end

        print(result.active)
        print(state)
        print(newstate)

        if newstate ~= currentstate then
            local updated = sql.Query("UPDATE survey_questions SET active = "..newstate.." WHERE rowid == "..sql.SQLStr(qid, false)..";")
            if updated ~= false then
                ulx.fancyLogAdmin(admin, true, "#A changed the state of question #s (#s) to #s", qid, result.question, newstate==1 and "enabled" or "disabled")
            else
                admin:ChatPrint("SQL-Fehler: "..sql.LastError())
            end
        else
            admin:ChatPrint("State didn't change.")
        end
    end
    function Survey:DeleteQuestion(admin, qid)
        -- Check, if question exists
        local result = sql.QueryValue("SELECT question FROM survey_questions WHERE rowid == "..qid..";")
        if not result then admin:ChatPrint("Question not found."); return end

        local deleteq = sql.Query("DELETE FROM survey_questions WHERE rowid == "..qid..";")
        if deleteq ~= false then
            ulx.fancyLogAdmin(admin, true, "#A deleted question #s (#s)", qid, result)
            local deletea = sql.Query("DELETE FROM survey_answers WHERE questionid == "..qid..";")
            if deleteq == false then
                admin:ChatPrint("SQL-Fehler: "..sql.LastError())
            end
        else
            admin:ChatPrint("SQL-Fehler: "..sql.LastError())
        end
    end

    net.Receive("SURVEY_GetPendingQuestion", function(_, user)
        if not (IsValid(user) and type(user) == "Player") then return end
        -- get groups of user
        local group = user:GetUserGroup()
        local groups = ""
        while group do
            if string.len(groups) > 0 then
                groups = groups..", "
            end
            groups = groups..sql.SQLStr(group)
            group = ULib.ucl.groupInheritsFrom( group )
        end
        local pendingid = sql.QueryValue("SELECT rowid FROM survey_questions WHERE active == 1 and questiongroup in ("..groups..") and '"..user:SteamID().."' not in (SELECT usersteamid FROM survey_answers WHERE survey_answers.questionid == survey_questions.rowid) LIMIT 1;")
        if not pendingid then print("Nothing pending..."); return end
        local question = sql.QueryRow("SELECT rowid,* FROM survey_questions WHERE rowid == "..pendingid..";")

        net.Start("SURVEY_PendingQuestion")
        net.WriteString(question.adminname)
        net.WriteString(question.adminrank)
        net.WriteInt(tonumber(question.rowid), 32)
        net.WriteString(question.question)
        net.WriteString(question.questiontype)
        net.WriteString(Survey:FormatTime(os.time() - question.date))
        net.Send(user)
    end)

    net.Receive("SURVEY_Answer", function(_, ply)
        if not IsValid(ply) then return end
        local username    = sql.SQLStr(ply:Nick(), true)
        local userrank    = sql.SQLStr(ply:GetUserGroup(), true)
        local usersteamid = ply:SteamID()
        local questionid  = tonumber(net.ReadInt(32))
        local qtype       = net.ReadString()
        local answer      = net.ReadString()
        -- Validate user data - first check, if this question exists
        local result = sql.QueryRow("SELECT questiontype,questiongroup FROM survey_questions WHERE rowid == "..sql.SQLStr(questionid, false).." and active == 1 and '"..ply:SteamID().."' not in (SELECT usersteamid FROM survey_answers WHERE survey_answers.questionid == survey_questions.rowid) LIMIT 1;")
        if not result then return end
        if result.questiontype ~= qtype then ply:ChatPrint("SurveyAnswer had wrong Questiontype!"); return end
        if not ply:CheckGroup(result.questiongroup) then ply:ChatPrint("You may not answer this question!"); return end
        -- seems ok
        result = sql.Query("INSERT INTO survey_answers (questionid, username, userrank, usersteamid, answer, date) VALUES ("..questionid..", '"..username.."', '"..userrank.."', '"..usersteamid.."', "..sql.SQLStr(answer)..","..os.time()..")")
        if result == false then
            print("SQL-Fehler: "..sql.LastError())
        else
            ply:ChatPrint("Thanks for your participation! :)")
        end
    end)

elseif CLIENT then

    -- Admin
    net.Receive("SURVEY_GetQuestions", function()
        local questions = net.ReadTable()

        local frame = vgui.Create("DFrame")
        frame:SetSize(800, 600)
        frame:SetTitle("List of Questions")
        frame:ShowCloseButton(true)
        frame:SetBackgroundBlur(false)
        frame:Center()

        local questionList = vgui.Create( "DListView", frame )
        questionList:SetPos( 5, 28 )
        questionList:SetSize( 790, 508 )
        questionList:SetMultiSelect(false)
        questionList:AddColumn("ID"):SetFixedWidth( 40 )
        questionList:AddColumn("Admin"):SetFixedWidth( 90 )
        questionList:AddColumn("Question"):SetFixedWidth( 380 )
        questionList:AddColumn("Type"):SetFixedWidth( 50 )
        questionList:AddColumn("Min Group"):SetFixedWidth( 80 )
        questionList:AddColumn("Started"):SetFixedWidth( 100 )
        questionList:AddColumn("Active?"):SetFixedWidth( 50 )
        questionList.DoDoubleClick = function( questionList, line ) RunConsoleCommand("ulx", "survey_get", tostring(questionList:GetLine( line ):GetValue( 1 ))) end
        questionList.OnRowRightClick = function( questionList, line )
            local DropDown = DermaMenu()
            DropDown:AddOption("View", function()
                local message = tostring(questionList:GetLine( line ):GetValue( 3 ))
                message = Survey:WordWrap(message)
                Derma_Message(message, "Full display", "Close")
            end)
            DropDown:AddOption("Open", function() RunConsoleCommand("ulx", "survey_get", tostring(questionList:GetLine( line ):GetValue( 1 ))) end )
            DropDown:AddOption("Toggle", function()
                local newstate = 1 - (questionList:GetLine( line ):GetValue(7) == "Yes" and 1 or 0)
                RunConsoleCommand("ulx", "survey_toggle", tostring(questionList:GetLine( line ):GetValue( 1 )), tostring( newstate ))
                questionList:GetLine( line ):SetValue( 7, newstate == 1 and "Yes" or "No" )
            end )
            DropDown:AddOption("Delete", function()
                RunConsoleCommand("ulx", "survey_delete", tostring(questionList:GetLine( line ):GetValue( 1 )) )
                frame:Close()
                RunConsoleCommand("ulx", "survey_get")
            end )
            DropDown:Open()
        end
        for k,v in pairs(questions) do
            -- questionList:AddLine(v.rowid, v.adminname.." ("..v.adminrank..")", v.question, v.questiontype, v.questiongroup, Survey:FormatTime(os.time() - tonumber(v.date)).." ago", v.active == "1" and "Yes" or "No")
            questionList:AddLine(v.rowid, v.adminname, v.question, v.questiontype, v.questiongroup, Survey:FormatTime(os.time() - tonumber(v.date)).." ago", v.active == "1" and "Yes" or "No")
        end

        local qtype_selected = nil
        local qgroup_selected = nil
        local questiontype = vgui.Create("DComboBox", frame)
        questiontype:SetPos(5, 540)
        questiontype:SetSize(130, 25)
        questiontype:AddChoice("accept") --"Nur zum Akzeptieren", "accept")
        questiontype:AddChoice("yesno") --"Zustimmen/Ablehnen", "yesno", true)
        questiontype:AddChoice("comment") --"Kommentieren", "comment")
        questiontype.OnSelect = function(index, value, data)
            qtype_selected = data
        end
        questiontype:ChooseOptionID(2)
        qtype_selected = questiontype:GetOptionText(2)

        local questiongroup = vgui.Create("DComboBox", frame)
        questiongroup:SetPos(140, 540)
        questiongroup:SetSize(130, 25)
        for _, v in ipairs( xgui.data.groups ) do
            if(v ~= "user") then
                questiongroup:AddChoice(v)
            end
        end
        questiongroup.OnSelect = function(index, value, data)
            qgroup_selected = data
        end
        questiongroup:ChooseOptionID(1)
        qgroup_selected = questiongroup:GetOptionText(1)

        local questionq = vgui.Create("DTextEntry", frame)
        questionq:SetPos(275, 540)
        questionq:SetSize(395, 25)
        questionq:SetText("Bei Risiken und Nebenwirkungen fragen Sie Ihren Arzt oder Pinguin!")

        local newquestionbutton = vgui.Create("DButton", frame)
        newquestionbutton:SetPos(675, 540)
        newquestionbutton:SetSize(120, 25)
        newquestionbutton:SetText("Ask question!")
        newquestionbutton.DoClick = function()
            RunConsoleCommand("ulx", "survey_ask", qtype_selected, qgroup_selected, questionq:GetText())
        end

        local newquestionicon = vgui.Create("DImageButton", newquestionbutton)
        newquestionicon:SetPos(2, 5)
        newquestionicon:SetMaterial("materials/icon16/add.png")
        newquestionicon:SizeToContents()

        local closebutton = vgui.Create("DButton", frame)
        closebutton:SetPos(5, 570)
        closebutton:SetSize(790, 25)
        closebutton:SetText("Close")
        closebutton.DoClick = function()
            frame:Close()
        end

        local close_icon = vgui.Create("DImageButton", closebutton)
        close_icon:SetPos(2, 5)
        close_icon:SetMaterial("materials/icon16/accept.png")
        close_icon:SizeToContents()

        frame:MakePopup()
    end)
    net.Receive("SURVEY_GetAnswers", function()
        local question = net.ReadTable()
        local answers  = net.ReadTable()

        PrintTable(question)
        for k,v in pairs(answers) do
            PrintTable(v)
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(800, 600)
        frame:SetTitle("Answers to a specific question")
        frame:ShowCloseButton(true)
        frame:SetBackgroundBlur(false)
        frame:Center()

        local questionlabel = vgui.Create("DLabel", frame)
        questionlabel:SetText(question[1].adminname.." ("..question[1].adminrank..") asked "..Survey:FormatTime(os.time() - tonumber(question[1].date)).." ago: "..question[1].question.." (Type: "..question[1].questiontype..", Active? "..(question[1].active and "yes" or "no")..")")
        questionlabel:SetTextColor( Color(255,0,0) )
        questionlabel:SetTextColor( Color(255,132,0) )
        questionlabel:SetWidth(790)
        questionlabel:SetPos(10, 28)

        local answerList = vgui.Create( "DListView", frame )
        answerList:SetPos( 5, 44 )
        answerList:SetSize( 790, 522 )
        answerList:SetMultiSelect(false)
        answerList:AddColumn("User (Rank)"):SetFixedWidth( 170 )
        answerList:AddColumn("Antwort"):SetFixedWidth( 520 )
        answerList:AddColumn("Datum"):SetFixedWidth( 100 )
        answerList.DoDoubleClick = function( answerList, line )
            if question[1].questiontype == "comment" then
                local message = tostring(answerList:GetLine( line ):GetValue( 2 ))
                message = Survey:WordWrap(message)
                Derma_Message(message, "Full display", "Close")
            end
        end
        for k,v in pairs(answers) do
            answerList:AddLine(v.username.." ("..v.userrank..")", v.answer:Trim(), Survey:FormatTime(os.time() - tonumber(v.date)).." ago")
        end

        local closebutton = vgui.Create("DButton", frame)
        closebutton:SetPos(5, 570)
        closebutton:SetSize(790, 25)
        closebutton:SetText("Close")
        closebutton.DoClick = function()
            frame:Close()
        end

        local close_icon = vgui.Create("DImageButton", closebutton)
        close_icon:SetPos(2, 5)
        close_icon:SetMaterial("materials/icon16/accept.png")
        close_icon:SizeToContents()

        frame:MakePopup()
    end)

    -- User
    hook.Add("TTTPrepareRound", "Survey_AskForQuestion", function()
        -- print("Ill ask the Server for a new question now!")
        net.Start("SURVEY_GetPendingQuestion")
        net.SendToServer()
    end)

    net.Receive("SURVEY_PendingQuestion", function()
        local adminname    = net.ReadString()
        local adminrank    = net.ReadString()
        local qid          = tonumber(net.ReadInt(32))
        local question     = net.ReadString()
        local questiontype = net.ReadString()
        local qdate        = net.ReadString()
        if not adminname or not adminrank or not qid or not question or not questiontype or not qdate then return end
        -- chat.AddText(Color(255, 128, 0), "[SURVEY]", color_white, " You have one pending question from ", Color(255, 128, 0), adminname.." ("..adminrank..")", color_white, ": ", Color(0,255,0), question)

        local frame = vgui.Create("DFrame")
        frame:SetSize(275, 170)
        frame:SetTitle(LocalPlayer():Nick()..", help us!")
        frame:ShowCloseButton(true)
        frame:SetBackgroundBlur(false)
        frame:Center()

        local questionintro = vgui.Create("DLabel", frame)
        questionintro:SetText(adminname.." ("..adminrank..") asked "..qdate.." ago:")
        questionintro:SizeToContents()
        questionintro:SetPos(10, 28)

        local questionlabel = vgui.Create("DLabel", frame)
        questionlabel:SetText(question)
        questionlabel:SetTextColor( Color(255,0,0) )
        questionlabel:SetTextColor( Color(255,132,0) )
        questionlabel:SetWidth(255)
        questionlabel:SetWrap(true)
        questionlabel:SetAutoStretchVertical(true)
        -- questionlabel:SizeToContents()
        questionlabel:SetPos(10, 44)

        if (questiontype == "accept") then
            local acceptbutton = vgui.Create("DButton", frame)
            acceptbutton:SetPos(5, 140)
            acceptbutton:SetSize(265, 25)
            acceptbutton:SetText("Thanks!")
            acceptbutton.DoClick = function()
                frame:Close()
                net.Start("SURVEY_Answer")
                net.WriteInt(qid, 32)
                net.WriteString(questiontype)
                net.WriteString("yes")
                net.SendToServer()
            end

            local rules_icon = vgui.Create("DImageButton", acceptbutton)
            rules_icon:SetPos(2, 5)
            rules_icon:SetMaterial("materials/icon16/accept.png")
            rules_icon:SizeToContents()
        elseif (questiontype == "yesno") then
            local yesbutton = vgui.Create("DButton", frame)
            yesbutton:SetPos(5, 110)
            yesbutton:SetSize(265, 25)
            yesbutton:SetText("Yes, I agree!")
            yesbutton.DoClick = function()
                frame:Close()
                net.Start("SURVEY_Answer")
                net.WriteInt(qid, 32)
                net.WriteString(questiontype)
                net.WriteString("yes")
                net.SendToServer()
            end

            local accepticon = vgui.Create("DImageButton", yesbutton)
            accepticon:SetPos(2, 5)
            accepticon:SetMaterial("materials/icon16/accept.png")
            accepticon:SizeToContents()

            local nobutton = vgui.Create("DButton", frame)
            nobutton:SetPos(5, 140)
            nobutton:SetSize(265, 25)
            nobutton:SetText("No, I disagree!")
            nobutton.DoClick = function()
                frame:Close()
                net.Start("SURVEY_Answer")
                net.WriteInt(qid, 32)
                net.WriteString(questiontype)
                net.WriteString("no")
                net.SendToServer()
            end

            local denybutton = vgui.Create("DImageButton", nobutton)
            denybutton:SetPos(2, 5)
            denybutton:SetMaterial("materials/icon16/stop.png")
            denybutton:SizeToContents()
        elseif (questiontype == "comment") then
            -- we need a bigger window:
            frame:SetSize(275,200)
            local comment = vgui.Create("DTextEntry", frame)
            comment:SetPos(5, 90)
            comment:SetSize(265, 75)
            comment:SetMultiline(true)
            -- comment:SetHeight(150)

            local commitbutton = vgui.Create("DButton", frame)
            commitbutton:SetPos(5, 170)
            commitbutton:SetSize(265, 25)
            commitbutton:SetText("Send my comment.")
            commitbutton.Think = function(self)
                local characters = string.len(string.Trim(comment:GetValue()))
                local disable = characters < 1
                commitbutton:SetDisabled(disable)
                commitbutton:SetText(disable and "You need to type something." or "Send my comment.")
            end
            commitbutton.DoClick = function()
                frame:Close()
                net.Start("SURVEY_Answer")
                net.WriteInt(qid, 32)
                net.WriteString(questiontype)
                net.WriteString(comment:GetValue())
                net.SendToServer()
            end

            local commiticon = vgui.Create("DImageButton", commitbutton)
            commiticon:SetPos(2, 5)
            commiticon:SetMaterial("materials/icon16/accept.png")
            commiticon:SizeToContents()
        end

        frame:MakePopup()
    end)
end

local function CreateCommand()
    if not ulx then return end

    function ulx.survey_ask(calling_ply, qtype, qgroup, question)
        Survey:AskQuestion(calling_ply, qtype, qgroup, question)
    end
    function ulx.survey_get(calling_ply, qid)
        Survey:GetQuestion(calling_ply, qid)
    end
    function ulx.survey_toggle(calling_ply, qid, state)
        Survey:ToggleQuestion(calling_ply, qid, state)
    end
    function ulx.survey_delete(calling_ply, qid)
        Survey:DeleteQuestion(calling_ply, qid)
    end

    local askquestion = ulx.command("Penguin", "ulx survey_ask", ulx.survey_ask, "!s_ask" )
    askquestion:addParam({
        type=ULib.cmds.StringArg,
        hint = "Type of the question (comment/yesno/accept)",
        default = "yesno"
    })
    askquestion:addParam({
        type=ULib.cmds.StringArg,
        completes=ulx.group_names_no_user,
        error="invalid group \"%s\" specified",
        hint="Lowest group to ask this question to.",
        default = "stammspieler",
        ULib.cmds.restrictToCompletes
    })
    askquestion:addParam({
        type=ULib.cmds.StringArg,
        hint="Question to ask.",
        default = "Do you like this server?",
        ULib.cmds.takeRestOfLine
    })
    askquestion:defaultAccess(ULib.ACCESS_ADMIN)
    askquestion:help("Ask a question to your userbase.")

    local getquestion = ulx.command("Penguin", "ulx survey_get", ulx.survey_get, "!s_get" )
    getquestion:addParam({
        type=ULib.cmds.NumArg,
        hint="ID of the question",
        default = 0,
        ULib.cmds.optional
    })
    getquestion:defaultAccess(ULib.ACCESS_ADMIN)
    getquestion:help("Ask a question to your userbase.")

    local togglequestion = ulx.command("Penguin", "ulx survey_toggle", ulx.survey_toggle, "!s_toggle" )
    togglequestion:addParam({
        type=ULib.cmds.NumArg,
        hint="ID of the question"
    })
    togglequestion:addParam({
        type=ULib.cmds.NumArg,
        hint="Desired active state (1 or 0)",
        default = -1,
        ULib.cmds.optional
    })
    togglequestion:defaultAccess(ULib.ACCESS_ADMIN)
    togglequestion:help("Toggle the active status of this question.")

    local deletequestion = ulx.command("Penguin", "ulx survey_delete", ulx.survey_delete, "!s_delete" )
    deletequestion:addParam({
        type=ULib.cmds.NumArg,
        hint="ID of the question"
    })
    deletequestion:defaultAccess(ULib.ACCESS_ADMIN)
    deletequestion:help("Delete this question.")
end
hook.Add("Initialize", "Survey_init", CreateCommand)

-- local query = sql.QueryValue("SELECT name FROM damagelog_names WHERE steamid = '"..steamid.."' LIMIT 1;")
-- if not query then
--      sql.Query("INSERT INTO damagelog_names (`steamid`, `name`) VALUES('"..steamid.."', "..sql.SQLStr(name)..");")
-- elseif query != name then
--      sql.Query("UPDATE damagelog_names SET name = "..sql.SQLStr(name).." WHERE steamid = '"..steamid.."' LIMIT 1;")

-- if v:IsAdmin() or v:IsUserGroup("operator") or v:IsUserGroup("Co Operator") then
--     local admins = 0
--     for k,v in pairs(player.GetAll()) do
-- function Damagelog.SlayMessage()
--     chat.AddText(Color(255,128,0), "[Autoslay] ", Color(255,128,64), net.ReadString())
-- end
