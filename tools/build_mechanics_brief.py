from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color
from reportlab.lib.utils import simpleSplit
from pypdf import PdfReader

from pathlib import Path
OUT = str(Path(__file__).resolve().parents[1] / 'output/pdf/chess-chaos-mechanics.pdf')
Path(OUT).parent.mkdir(parents=True, exist_ok=True)
W,H=595.28,841.89
c=canvas.Canvas(OUT,pagesize=(W,H))
c.setTitle('Chess, Then Chaos | Mechanics Notebook')
c.setAuthor('Game concept notebook')
ink=HexColor('#172D29'); muted=HexColor('#52625B'); green=HexColor('#27715A'); orange=HexColor('#CB613B'); paper=HexColor('#F7F5EE')

def text(x,y,s,size=10,color=ink,font='Helvetica'):
 c.setFillColor(color); c.setFont(font,size); c.drawString(x,y,s)
def wrap(s,x,y,width=499,size=10.5,leading=15,color=ink,font='Helvetica'):
 for line in simpleSplit(s,font,size,width):
  text(x,y,line,size,color,font); y-=leading
 return y

def base(n,label):
 c.setFillColor(paper); c.rect(0,0,W,H,fill=1,stroke=0)
 text(48,801,'CONCEPT NOTEBOOK  /  37',9,green,'Helvetica-Bold')
 text(48,32,'30 OCT 2026  |  v0.37  |  Confirmed direction + open proposals',8,muted)
 text(492,32,f'{n} / 4',8,muted)
 c.setStrokeColor(HexColor('#D7DED3')); c.line(48,48,547,48)

def label(y,s):
 text(48,y,s.upper(),9,green,'Helvetica-Bold'); return y-22

def entry(y,name,body):
 text(48,y,name,12,ink,'Helvetica-Bold')
 return wrap(body,48,y-15,size=10.5)-5

base(1,'Army')
text(48,752,'Chess, then chaos.',32,ink,'Helvetica-Bold')
text(48,727,'A series of chess games. An increasingly ridiculous army.',12,muted)
y=wrap('Chess escalates through pieces, upgrades, and terrain. Open rules: page 2.',48,710,size=11,leading=16)-10
y=label(y,'01 / New pieces')
y=entry(y,'Portals','Friendly units traverse a linked portal pair, continuing the same trajectory. Enemies cannot.')
y=entry(y,'Ghost','Moves like a rook, is not obstructed by other units, and can capture only the king.')
y=entry(y,'Elephant','Moves two squares horizontally or vertically, capturing up to two enemies along that path in one move.')
y=entry(y,'Bouncer','Moves one square in any direction; pushes an adjacent unit until it hits something instead of capturing.')
y=entry(y,'Seductress','Converts enemies to its side instead of capturing. Movement and range remain open.')
y=entry(y,'Factory','Cannot move. Every turn, creates a pawn on the square directly in front of it if that square is empty.')
y=label(y,'02 / Unit upgrades')
y=entry(y,'Phasing','A rook (tower) can pass through units without its movement being blocked.')
y=entry(y,'+1 / +2','+1 grants two actions per turn; +2 grants three. Both mix movement and attacks. +2 becomes available late, when opponents are also extremely powerful. Stacking is open.')
y=entry(y,'Assassin Dagger','Hidden from the opponent. When the carrier is captured, the capturing unit dies too.')
y=entry(y,'Gun','Visible and single-use. Shoot along a direction, killing the first unit in sight; then consume the Gun.')
y=entry(y,'Recoil','After capturing, the unit returns to the square it attacked from.')
y=entry(y,'Voidwalker','Moves normally on an imagined infinite board. Normal capture geometry still applies. An off-board captor without Voidwalker dies; one with Voidwalker survives.')
y=entry(y,'Eldritch','Whenever this unit moves, remove the board square it moved from.')
c.showPage()
base(2,'Battlefield')
text(48,752,'Change the battlefield',28,ink,'Helvetica-Bold')
text(48,729,'Army rules, board modifiers, and combinations to explore.',11,muted)
y=label(689,'03 / General improvements')
y=entry(y,'Backup',"When the carrier is captured, cancel the attacking unit's movement. The attacker stays on its original square; the captured unit becomes a friendly rook on the same square.")
y=entry(y,'Twin Regents','Replace king and queen with two identical nonbinary Regents. Both have strong movement sets, weaker than the queen. Both must be captured to defeat their owner. Placement in this category is provisional.')
y=label(y,'04 / Board modifiers')
y=entry(y,'10 x 10 Board','Expand the board to 10 x 10 and grant two additional rooks and two additional special units.')
y=entry(y,'Horizontal Wrap','Connect left and right edges periodically; keep top and bottom separate. On an 8-file board, a bishop moving northeast from h4 continues to a5.')
y=entry(y,'Brittle Board','After each turn, one square breaks away, starting at the outside and crumbling inward.')
y=entry(y,'Conveyor Belt','A fixed clockwise roundabout spans the two empty ranks in front of your army (ranks 3 and 4), across the full board width. Units advance one tile after each completed turn. The loop persists between battles and resizes on larger boards.')
y=entry(y,'Walls','Place walls in your half during preparation. Units cannot cross them. Layout, projectile blocking, and interaction with jumping or portals remain open.')
y=entry(y,'Buried Mines','Bury mines in your half during preparation. Concealment, triggers, and damage remain open.')
y=label(y,'Preparation and run structure')
y=wrap('Pawns keep their types and positions; upgrades remain allowed. Other paired pieces and upgrades mirror left/right. Edit terrain in your half. Conveyors use a fixed roundabout; terrain persists between battles. The king/queen center remains the unique-piece exception.',48,y,size=10.5,leading=15)-17
y=label(y,'Rules to resolve / not decided')
y=wrap('Actions: Gun directions/cost; Regent movement; Ghost targets; +1/+2 stacking; Elephant blockers; Factory timing. Seductress: movement, conversion range, royal eligibility, equipment allegiance, and action timing for converted units.',48,y,size=10,leading=14)-8
y=wrap('Resolution: Backup with Dagger or multi-captures; Recoil return squares; Bouncer collisions and friendly targets; capture effects, collapse and simultaneous terrain movement.',48,y,size=10,leading=14)-8
y=wrap('Board: conveyor collisions, mines, collapse, portals and walls; Voidwalker with wrap and holes; Eldritch with forced movement. Prototype choices: page 4.',48,y,size=10,leading=14)
c.showPage()
base(3,'Opponents')
text(48,752,'Opponents with a personality',26,ink,'Helvetica-Bold')
text(48,729,'Design proposals / enemy progression and game AI',11,muted)
y=label(690,'A / Authored archetypes + generated variations')
y=wrap('Build themed enemy templates, then vary their units, upgrades, formations, and terrain on the enemy half within a difficulty budget. Use fully authored bosses. Introduce a mechanic clearly before combining it with others; budgets are a first estimate, not proof of balance.',48,y,size=11,leading=16)-18
y=entry(y,'Example opponent families','The Shooting Club: rooks with visible single-use Guns. The Night Shift: Ghosts and Phasing. The Moving Company: Bouncers and Conveyor Belt. Later encounters combine a main identity with a supporting mechanic.')
y=wrap('Validate deployment, mobility, board compatibility, and obvious forced opening losses. Track win rates and game length; playtest for readable counterplay. These checks cannot guarantee fairness.',48,y,size=10.5,leading=15)-20
y=label(y,'B / One simulator, shared by play and AI')
y=wrap('The rules engine lists legal actions and resolves their full consequences on a copied board. The AI tries continuations, considers enemy replies, and scores the results. New mechanics must work in the simulator before they enter the reward pool.',48,y,size=11,leading=16)-18
y=entry(y,'First prototype: bounded tactical search','Start with shallow adversarial lookahead and a handcrafted evaluation: royal survival, immediate threats, mobility, equipment, and board hazards. Search complete turns, including +1/+2 actions and end-turn board effects. Extra actions expand search. Voidwalker adds infinitely many sliding destinations: test a finite candidate set without changing the stated rules. Try Monte Carlo Tree Search later if profiling justifies it.')
y=entry(y,'Resolve effects consistently','Define a fixed event order for movement, captures, death effects, replacement, Recoil, conveyors, collapse, and victory. The live game and AI must use the same resolver; unresolved interactions cannot be left to the AI to invent.')
y=entry(y,'Hidden information and personality','The AI sees its own equipment and public information, not the hidden enemy Dagger. Evaluate plausible hidden loadouts from permitted observations. Enemy personalities prefer certain good moves; tune foresight and risk tolerance rather than relying on arbitrary blunders.')
y=label(y,'Prototype gate / recommendation')
y=wrap('Start with ordinary pieces, +1, Recoil, and one board effect. Check legality, tactics, extra actions, hazard avoidance, and turn time. Add multi-captures, portals, and hidden equipment in stages; entertaining play requires testing.',48,y,size=10.5,leading=15)-16

y=wrap('Fairy-Stockfish supports custom variants; suitability for these exact mechanics is unproven. OpenSpiel provides a general simulation-based MCTS example.',48,y,size=9,leading=12)-5
text(48,y,'fairy-stockfish.github.io  |  github.com/google-deepmind/open_spiel',9,green)
c.linkURL('https://fairy-stockfish.github.io/',(48,y-2,185,y+11),relative=0)
c.linkURL('https://github.com/google-deepmind/open_spiel/blob/master/open_spiel/python/algorithms/mcts.py',(190,y-2,530,y+11),relative=0)
c.showPage()
base(4,'Implementation')
text(48,752,'Now playable in the sandbox',26,ink,'Helvetica-Bold')
text(48,729,'Prototype implementation / provisional rules, 30 October 2026',11,muted)
y=label(689,'Debug shop / three categories')
y=entry(y,'Pieces, unit upgrades, board upgrades','The current concepts on pages 1 and 2 are implemented; Hunter is removed. Open the parallel chess sandbox scene in Godot and press F6. Choose a free item, then click its target; board switches apply immediately. Pawns stay fixed; paired replacements and upgrades mirror. Terrain stays in your half. Start battle explicitly.')
y=entry(y,'Mixed victory conditions','Ordinary kings retain check and checkmate, including in upgraded battles; stalemate draws. Regents must both be captured. Variant castling/en passant and repetition/fifty-move draws remain disabled.')
y=entry(y,'Extra actions','Extra actions stay with the acting piece. +1 grants two moves or attacks; +2 grants three. These upgrades replace one another instead of stacking. End bonus turn skips unused actions.')
y=entry(y,'Cancellation and terrain','Backup cancels the whole attack and consumes itself. Earlier multi-capture effects roll back. After surviving captures: movement, Eldritch, arrival mine, then Recoil if possible. End turns advance belts, collapse one outer tile, switch side and spawn Factory pawns.')
y=entry(y,'Infinite space and hidden information','Voidwalker reveals clickable void cells. Pan, zoom and Home navigate them; coordinate entry remains optional and distant pieces stay selectable. AI searches finite nearby candidates plus occupied distant targets. Enemy Daggers and mines are omitted from its private copy. The simulator resolves actions deterministically.')
y=entry(y,'A series of increasingly silly battles','Next battle restores your starting build and player terrain, then opens preparation against themed upgraded opponents. No profile persistence or reward economy. Strength, balance and rendering still need human playtests.')
y=label(y,'Detailed implementation decisions')
y=wrap('docs/chaos-sandbox.md records every provisional interaction and the test commands. This appendix describes the prototype; earlier open-rule notes remain design questions, not claims of final agreement.',48,y,size=10.5,leading=15)
c.save()
r=PdfReader(OUT)
assert len(r.pages)==4
for p in r.pages: assert len(p.extract_text())>1000
print(OUT)
print('Validated: 4 pages; text present on every page.')
