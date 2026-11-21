local ns, db = NS, BlockForgeDB
assert(table.pack == nil and table.unpack == nil and utf8 == nil and os == nil and io == nil)
local rec = { label = "test", ops = {} }
ns.SetUndo(rec)
assert(rec.owner == ns.CharKey(), "undo owner missing")
assert(ns.UndoLabel() == "test")
local unitName = UnitName
UnitName = function() return "Other" end
assert(ns.UndoLabel() == nil, "foreign undo visible")
assert(ns.RunUndo() == nil and db.undo == rec, "foreign undo replayed")
UnitName = unitName
rec.owner = nil
assert(ns.UndoLabel() == nil and ns.RunUndo() == nil and db.undo == rec, "legacy undo replayed")
ns.SetUndo({label="own", ops={}})
assert(ns.RunUndo() == 0 and db.undo == false, "own undo refused")

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers+1] = {delay,fn} end }
local function tick() local old=timers timers={} for _,t in ipairs(old) do t[2]() end end
local items = {[118]="Minor",[929]="Middle"}
local bags = {929,13446}
C_Container = {GetContainerNumSlots=function(bag) return bag==0 and #bags or 0 end, GetContainerItemID=function(_,slot) return bags[slot] end}
C_Item.GetItemNameByID=function(id) return items[id] end
C_Item.GetItemInfo=function(id) return items[id] end
local requested={}
C_Item.RequestLoadItemDataByID=function(id) requested[id]=true end
CreateMacro("Cold",1,"/use Middle")
db.living.account.Cold={template="/use {bf:potion_soin}",body="/use Middle",last={["{bf:potion_soin}"]="Middle"}}
assert(ns.Living.Pass()==0 and requested[13446] and #timers==1 and timers[1][1]==2, "cold cache not postponed")
items[13446]="Major"
fireEvent("GET_ITEM_INFO_RECEIVED",13446,true)
assert(MACROS.Cold.body=="/use Major", "cache event did not resume")
tick()
items[13446]=nil
for i=1,5 do assert(ns.Living.Pass()==0) assert(timers[1] and timers[1][1]==2) tick() end
assert(MACROS.Cold.body=="/use Major", "cold cache downgraded macro")
assert(#timers==0, "retry limit exceeded")
items[13446]="Major" items[118]=nil
bags={929,118}
db.living.account.Cold.last={}
ns.Living.Pass()
assert(MACROS.Cold.body=="/use Major", "missing history allowed a downgrade")
items[118]="Minor" items[13446]=nil bags={929,13446}
db.living.account.Cold.last={["{bf:potion_soin}"]="Major"}
local hooks=0
MacroFrame={IsShown=function() return true end, HookScript=function(self,event,fn) hooks=hooks+1 self.hide=fn end}
items[13446]="Newest"
assert(ns.Living.Pass()==0 and MACROS.Cold.body=="/use Major", "pass ran with MacroFrame shown")
ns.Living.Pass() assert(hooks==1, "MacroFrame hooked twice")
MacroFrame.IsShown=function() return false end
MacroFrame.hide() tick()
assert(MACROS.Cold.body=="/use Newest", "MacroFrame close did not resume")
MacroFrame=nil
local calls=0
ns.KitsUI.Ready=function() calls=calls+1 return {} end
db.kits[ns.CharKey()]={waiting={test=true}}
ns.KitsUI.Watch() calls=0
for i=1,8 do fireEvent("SPELLS_CHANGED") fireEvent("PLAYER_REGEN_ENABLED") end
assert(calls==0, "kits ran before timer")
tick() assert(calls==1, "kits burst not coalesced")
local n=#db.errors
fireEvent("ADDON_ACTION_BLOCKED","AnotherAddon","EditMacro")
fireEvent("ADDON_ACTION_FORBIDDEN","BlockForge","SetBinding")
assert(#db.errors==n+1 and db.errors[#db.errors].message:find("SetBinding",1,true), "blocked action filtering")

ns.Open("macros")
local row = find(function(w) return w.scope and w.text and w.text._text=="Cold" end)
assert(row and row.scope._text == ns.L["Macro vivante"], "wrong scope label")
ns.SetFeature("welcomeMotion",false)
ns.OpenWelcome()
assert(ns.Welcome.panel.demo[3].text._text==ns.L["Vivantes"])
assert(ns.Welcome.panel.demo[3]._w >= 8*6+12, "French chip clipped")
if GetLocale()=="enUS" then
  assert(row.scope._text=="Living" and ns.L["Vivante"]=="Alive")
  assert(byText("Alive", ns.ed.w.insp).text._text=="Alive", "nodead chip renamed")
end
items[13446]=nil
fireEvent("PLAYER_ENTERING_WORLD")
assert(db.selftest.cold==1, "cold counter missing")
local out={}
C_Spell.IsSpellUsable=function() error("probe error text") end
ns.ReleaseProbes(out)
local text=table.concat(out,"\n")
for _,id in ipairs({2,3,4,5,6,7,9,12,14,15,16,17,18,19,20,21}) do assert(text:find("INFO V"..id.." ",1,true), "probe missing "..id) end
assert(text:find("probe error text",1,true))
local sent=#SENT
COMBAT=true
SlashCmdList.BLOCKFORGE("sonde")
assert(not ns.probeFrame and #SENT==sent, "combat probe side effects")
COMBAT=false
local override,cleared,sets,callback=nil,0,0,nil
SetOverrideBindingClick=function(frame,priority,key,name) assert(key=="CTRL-SHIFT-F12" and name=="BlockForgeProbeButton") sets=sets+1 override="CLICK "..name..":LeftButton" end
ClearOverrideBindings=function() cleared=cleared+1 override=nil end
GetBindingAction=function(_,check) return check and override or "" end
EventRegistry={RegisterCallback=function(_,event,fn) assert(event=="SetItemRef") callback=fn end}
local links={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,line) links[#links+1]=line end}
WIDGET.SetFrameStrata=function(self,strata) self._strata=strata end
WIDGET.RegisterForClicks=function(self,up,down) assert(up=="AnyUp" and down=="AnyDown") self.clicks=true end
WIDGET.SetAttribute=function(self,key,value) self[key]=value end
SlashCmdList.BLOCKFORGE("probe")
assert(ns.probeFrame:IsShown() and ns.probeFrame._strata=="DIALOG")
assert(ns.probeButton.clicks and ns.probeButton.type=="macro" and ns.probeButton.macrotext=="/run BlockForgeDB.selftest.clicked=true")
assert(sets==1 and cleared==1 and not override and db.selftest.probe.V10:find("CLICK",1,true))
assert(db.selftest.probe.V8==0, "addon return code was not preserved")
assert(#SENT==sent+1 and SENT[#SENT][3]=="WHISPER" and SENT[#SENT][4]==UnitName("player"), "probe messaged someone else")
assert(links[1]:find("|Haddon:BlockForge:probe|h",1,true))
callback(ns,"addon:Other:probe") assert(not db.selftest.link)
callback(ns,"addon:BlockForge:probe") assert(db.selftest.link)
local probe=db.selftest.probe
ns.SelfTest()
assert(db.selftest.probe==probe and db.selftest.cold==1 and db.selftest.link and probe.V13==true)
fire(byText(ns.L["Terminé"],ns.probeFrame),"OnClick")
assert(not ns.probeFrame:IsShown())
GetBindingAction=function() return "ACTIONBUTTON1" end
SlashCmdList.BLOCKFORGE("sonde")
assert(sets==1 and db.selftest.probe.V10=="occupied", "occupied key changed")

-- Le journal reste borne et ignore les autres add-ons.
for i=1,25 do fireEvent("ADDON_ACTION_BLOCKED","BlockForge","action"..i) end
assert(#db.errors==20 and db.errors[20].message:find("action25",1,true))
-- Une erreur apres la pose de la touche ne saute jamais le nettoyage.
GetBindingAction=function(_,check) if check and override then error("binding read error") end return "" end
SlashCmdList.BLOCKFORGE("probe")
assert(sets==2 and cleared==2 and not override and db.selftest.probe.V10:find("binding read error",1,true))
-- Les sondes automatiques n'ecrivent ni touche ni message et chaque erreur reste INFO.
local priorSets, priorSent=sets,#SENT
local absent={}
C_Secrets=nil C_RestrictedActions=nil C_EditMode=nil SOUNDKIT=nil Enum=nil C_ActionBar=nil C_SpecializationInfo=nil SecureCmdOptionParse=nil
C_Spell.IsSpellUsable=nil C_Spell.IsSpellInRange=nil C_Spell.GetSpellCooldown=nil
ns.ReleaseProbes(absent)
for _,line in ipairs(absent) do assert(line:find("^INFO ")) end
assert(sets==priorSets and #SENT==priorSent)
local effectCalls=0
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 40 or 0 end
C_Container.GetContainerItemID=function(_,slot) return slot end
C_Item.GetItemInfoInstant=function(id) return id,nil,nil,nil,nil,0,5 end
C_Item.GetItemSpell=function() effectCalls=effectCalls+1 return "Food",123 end
ns.ReleaseProbes({})
assert(effectCalls==20, "V18 exceeded twenty items")
-- Une attente en cours est abandonnee quand la fonction est coupee.
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
C_Container.GetContainerItemID=function(_,slot) return bags[slot] end
ns.Living.Pass()
local waitingFrame = find(function(w) return w._events.UNIT_PET and w._events.GET_ITEM_INFO_RECEIVED end)
assert(waitingFrame)
ns.SetFeature("living",false)
assert(not waitingFrame._events.GET_ITEM_INFO_RECEIVED)
tick()
assert(ns.Living.retries==0 and not ns.Living.scheduled)
