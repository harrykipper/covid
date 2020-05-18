__includes ["DiseaseConfig.nls" "output.nls" "SocialNetwork.nls" "layout.nls"]

extensions [csv table]

undirected-link-breed [households household]
undirected-link-breed [relations relation]   ;; Relatives who don't live in the same household
undirected-link-breed [friendships friendship]
undirected-link-breed [tracings tracing]     ;; The contact tracing app
undirected-link-breed [classes class]        ;; Schools

globals
[
  rnd                  ;; Random seed
  N-people

  tests-remaining      ;; Counters for tests
  tests-per-day
  tests-performed

  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-infected-previous ;; Number of infected people at the previous tick
  nb-recovered         ;; Number of recovered people at the end of the tick

  in-hospital          ;; Number of people currently in hospital
  hospital-beds        ;; Number of places in the hospital (currently unused)

  contact-tracing      ;; If true a contact tracing app exists

  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  s0                   ;; Initial number of susceptibles
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population

  lockdown?            ;; If true we are in a state of lockdown

  counters             ;; Table containing various information
  howmanyrnd
]

turtles-own
[
  sex
  age
  status               ;; Marital status 0 = single 1 = married 2 = divorced 3 = widowed

  infected?            ;; If true, the person is infected.
  cured?               ;; If true, the person has lived through an infection. They cannot be re-infected.
  symptomatic?         ;; If true, the person is showing symptoms of infection
  severe-symptoms?     ;; If true, the person is showing severe symptoms
  isolated?            ;; If true, the person is isolated at home, unable to infect friends and passer-bys.
  days-isolated        ;; Number of days the agent has spent in self-isolation
  hospitalized?        ;; If true, the person is hospitalized.
  dead?                ;; If true, the person is... you know..
  infected-by          ;; Agent who infected me
  spreading-to         ;; Agents infected by me

  infection-length     ;; How long the person has been infected.
  recovery-time        ;; Time (in days) it takes before the person has a chance to recover from the infection
  symptom-time         ;; Time (in days) it takes before the person shows symptoms
  infectivity-time     ;; Time (in days) it takes before an infected person becomes infectious
  cured-since          ;; Day the person was cured

  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine when symptomatic.
  testing-urgency      ;; When the person will seek to get tested after the onset of symptoms

  susceptible?         ;; Tracks whether the person was initially susceptible

  has-app?             ;; If true the agent carries the contact-tracing app
  tested-today?        ;; The agent
  aware?
  visited-relations-this-week    ; Who have I seen this week?
]

links-own [mean-age removed?]
households-own [ltype]  ; ltype 0 is a spouse; ltype 1 is offspring/sibling
tracings-own [day]

;; ===========================================================================
;;;
;;; SETUP
;;;
;; ==========================================================================

to setup

  set rnd  1580319122 ; 1304196825
  if use-seed? = false [
    set rnd new-seed
  ]
  random-seed rnd
  show rnd ;if behaviorspace-run-number = 0 [output-print (word  "Random seed: " rnd)]

  clear-all

  ;set counters table:make

  ;if impossible-run [
  ;  reset-ticks
  ;  stop
  ;]

  set-default-shape turtles "circle"
  ifelse pct-with-tracing-app > 0 [set contact-tracing true][set contact-tracing false]

  read-agents
  set N-people count turtles
  set howmanyrnd round (N-people * 0.001) ;; Number of people we meet at random every day. 1 per 1000 residents.

  if use-network? [
    ifelse use-existing-nw? = true
    [
      import-network
      if schools-open? [create-schools]
    ]
    [
      create-hh
      ask turtles with [age >= 65] [create-relations]

      make-initial-links
      if schools-open? [create-schools]
      create-friendships
    ]
    ask turtles [
      assign-tendency
      reset-variables
    ]

    ask links [set removed? false]

    if show-layout [
      resize-nodes
      repeat 50 [layout]
    ]
  ]
  set counters table:from-list (list ["household" 0]["relations" 0]["friends" 0]["school" 0]["random" 0])
  ;set populations table:from-list (list ["susceptible" 0]["infected" 0]["recovered" 0]["dead" 0])

  reset-ticks

  infect-initial-agents
  set s0 count turtles with [susceptible?]
  if behaviorspace-run-number = 0 [output-print (word "Infected agents: " [who] of turtles with [infected?])]

  set tests-per-day round ((tests-per-100-people / 100) * N-People / 7)
  set tests-remaining tests-per-day
  set tests-performed 0

  let adults turtles with [age > 14]
  ask n-of (round count adults * (pct-with-tracing-app / 100)) adults [set has-app? true]
  set lockdown? false
end

to infect-initial-agents
  ask n-of (round (N-people / 100) * initially-infected) turtles with [age > 25][
    set infected? true
    set susceptible? false
  ]
end

to reset-variables
  set has-app? false
  set cured? false
  set isolated? false
  set hospitalized? false
  set infected? false
  set susceptible? true
  set symptomatic? false
  set severe-symptoms? false
  set dead? false
  set aware? false
  set cured-since 0
  set spreading-to 0
  set infected-by nobody
end

to read-agents
  let row 0
  foreach csv:from-file "vo.csv" [ag ->
    let i 1
    if row > 0 [
      while [i < length ag][
        crt item i ag [
          set age item 0 ag + 1 ;; ISTAT data are from 2019, everyone is one year older now..
          ifelse i < 5 [set sex "M"][set sex "F"]
          ifelse i = 1 or i = 5 [set status 0][
            ifelse i = 2 or i = 6 [set status 1][
              ifelse i = 3 or i = 7 [set status 2][set status 3
                ;ifelse i = 4 or i = 8 [set status 3][set status 4]
              ]
            ]
          ]
        ]
        set i i + 1
      ]
    ]
    set row row + 1
  ]
end

;=====================================================================================

to go
  ;if behaviorspace-run-number != 0 and ticks = 0 [if impossible-run [stop]]

  if all? turtles [ not infected? ][
    ifelse behaviorspace-run-number = 0
    [print-final-summary]
    [save-output]
    ;[ let deaths count turtles with [dead?]
    ;  if deaths > 2 and deaths / (deaths + count turtles with [cured?]) < 5 [ save-output ]
    ;]
    stop
  ]

  clear-count     ; this is to compute R0 the epiDEM's way

  set tests-remaining tests-remaining + tests-per-day

  ask turtles [set tested-today? false]
  if ticks mod 7 = 0 [ask turtles [set visited-relations-this-week nobody]]

  if contact-tracing [ask tracings with [day <= (ticks - 10)][die]]

  ask turtles with [isolated?] [
    set days-isolated days-isolated + 1
    if (symptomatic? = false and days-isolated = 10) [unisolate]
  ]

  ask turtles with [infected?] [
    set infection-length infection-length + 1

    if not hospitalized? [
      ;; If you're in hospital you don't infect anyone. If you're isolated you can infect members of your household
      infect
      if severe-symptoms?  [ hospitalize ]
    ]

    if symptomatic? and (should-test? self) and (infection-length = testing-urgency) [
      ifelse tests-remaining > 0
      [get-tested]
      [
        maybe-isolate
        let needisolating household-neighbors with [should-isolate? self]
        if visited-relations-this-week != nobody and should-isolate? visited-relations-this-week [
          set needisolating (turtle-set needisolating visited-relations-this-week)]
        ask needisolating [maybe-isolate]
        if has-app? [ask tracing-neighbors with [should-isolate? self] [maybe-isolate]]
      ]
    ]

    ;; Progression of the infection
    if severe-symptoms? and infection-length = recovery-time [maybe-die]
    if symptomatic? and (not severe-symptoms?) and infection-length = recovery-time [maybe-worsen]
    if (not symptomatic?) and (infection-length = symptom-time) [maybe-show-symptoms]

    ;; If we get to this stage we are safe.
    if infection-length > recovery-time [recover]
  ]

  if show-layout [ask turtles [assign-color]]
  calculate-r0
  if behaviorspace-run-number != 0 [ save-individual ]

  tick
end

to clear-count
  set nb-infected 0
  set nb-recovered 0
end


;; =========================================================================
;;                    PROGRESSION OF THE INFECTION
;; =========================================================================

;; After the incubation period the person may be showing symptoms.
;; If they do the infection length counter is reset and the infection will progress to the next stage.
;; If they don't the infection will finish its course and the person will be healed, eventually.
to maybe-show-symptoms
  if prob-symptoms > random 100 [
    ;show "DEBUG: I have the symptoms!"
    set symptomatic? true
    set infection-length 0
  ]
end

;; If the person worsens, after another 7 days he will either die or heal.
to maybe-worsen
  if probability-of-worsening age * gender-discount > random 100 [
    set severe-symptoms? true
    set recovery-time round (infection-length + random-normal 7 2 )
  ]
end

to maybe-die
  ifelse hospitalized?
  [if probability-of-dying age > random 100 [kill-agent]]
  [if (probability-of-dying age) * 1.5 > random 100 [kill-agent]]  ; no hospital bed means a dire fate
end

to recover
  set infected? false
  set symptomatic? false
  set cured? true
  set cured-since ticks
  if isolated? or hospitalized? [unisolate]
  set nb-recovered (nb-recovered + 1)
  if hospitalized? [set in-hospital (in-hospital - 1)]
end

to kill-agent
  ask my-friendships [die]
  ask my-households [die]
  ask my-relations [die]
  ask my-classes [die]
  set dead? true
  if hospitalized? [
    set hospitalized? false
    set in-hospital (in-hospital - 1)
  ]
  set cured-since ticks
  if count turtles with [dead?] = 1 [
    if lockdown-at-first-death [lockdown]
    if behaviorspace-run-number = 0 [
      output-print (word "Epidemic day " ticks ": death number 1. Age: " age "; gender: " sex)
      output-print (word "Duration of agent's infection: " symptom-time " days incubation + " infection-length " days of illness")
      print-current-summary
    ]
  ]
end

;; ===============================================================================

to-report gender-discount
  if sex = "F" [report 0.8]
  report 1
end

to-report should-test? [agent]
  let te 0
  ask agent [if not tested-today? and not aware? [set te 1]]
  ifelse te = 1 [report true][report false]
end

to-report should-isolate? [agent]
  let is 0
  ask agent [if not isolated? and not aware? and not tested-today? [set is 1]]
  ifelse is = 1 [report true][report false]
end

to maybe-isolate
  let tendency isolation-tendency
  if not symptomatic? [set tendency tendency * 0.7]
  if random 100 < tendency [isolate]
end

;; When the agent is isolating all friendhips and relations are frozen. If she goes to school, she stops.
;; Crucially household links stay in place, as it is assumed that one isolates at home
;; Other household members may also have to isolate.
to isolate
  set isolated? true
  ask my-friendships [set removed? true]
  ask my-relations [set removed? true]
  ask my-classes [set removed? true]
end

;; After unisolating, links return in place
to unisolate  ;; turtle procedure
  set isolated? false
  set days-isolated 0
  if hospitalized? [
    set hospitalized? false
    set in-hospital (in-hospital - 1)
  ]
  ask my-links with [removed? = true][set removed? false]
end

;; To hospitalize, remove all links.
to hospitalize ;; turtle procedure
  set hospitalized? true
  set aware? true
  set in-hospital in-hospital + 1

  ;; We assume that hospitals always have tests. If I end up in hospital, the app will tell people.
  ask tracing-neighbors with [should-test? self] [
    ifelse tests-remaining > 0
    [get-tested]
    [maybe-isolate]
  ]

  ask my-links [set removed? true]
  set isolated? true
  set pcolor black

  if show-layout [
    move-to patch (max-pxcor / 2) 0
    set pcolor white
  ]
end

;=====================================================================================

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible friends and family.
;; We allow people to meet others even before they are infective so that the app will record these
;; interactions and produce a few false positives

to infect  ;; turtle procedure
  let spreader self
  let infectious? infection-length >= infectivity-time

  ;; Here we define the unknown people we encounter. This is the 'random' group.
  ;; If we are isolated or there is a lockdown, this is assumed to be zero.
  ;; If not, it is assumed to be 1/1000 of the population, 1/3 elderly.
  let random-passersby nobody
  if isolated? = false and lockdown? = false and (age <= 65 or ticks mod 2 = 0) [
    ifelse use-network?
    [set random-passersby (turtle-set
      n-of random (round howmanyrnd * 0.66) other turtles with [age <= 65]
      n-of random (round howmanyrnd * 0.33) other turtles with [age > 65])
    ]
    [set random-passersby (turtle-set
      n-of random (round (howmanyrnd * 10) * 0.66) other turtles with [age <= 65]
      n-of random (round (howmanyrnd * 10) * 0.33) other turtles with [age > 65])
    ]
  ]

  if use-network? [

    if age <= 67 or ticks mod 2 = 0 [      ;; Old people only meet friends on even days (= go out half of the times younger people do).

      let proportion 10
      if any? my-classes [set proportion 20]  ;; Children who go to school will meet less friends
      ;let young-ppl friendship-neighbors with [age < 65]
      ;let old-ppl friendship-neighbors with [age >= 65]

      let all-ppl friendship-neighbors

      ;;; Every day the agent meets a certain fraction of her friends.
      ;;; If the agent has the contact tracing app, a link is created between she and the friends who also have the app.
      ;;; If the agent is infective, with probability infection-chance the agent the infects the susceptible friends who she is meeting.
      if count all-ppl > 0 [
        let howmany (1 + random round (count all-ppl / proportion))
        if howmany > 50 [set howmany 50]
        ask n-of howmany all-ppl [
          if (not infected?) and (not aware?) and [removed?] of friendship-with spreader = false [
            if has-app? and [has-app?] of spreader [add-contact spreader]
            if infectious? and (not cured?) and random 100 < infection-chance [newinfection spreader "friends"]]
        ]
      ]
    ]

    ;; Schoolchildren meet their schoolmates every day, and can infect them.
    if schools-open? and any? class-neighbors [
      ask class-neighbors [
        if (not infected?) and (not aware?) and (not [removed?] of class-with spreader) [
          if has-app? and [has-app?] of spreader [add-contact spreader]
          if infectious? and (not cured?) and random 100 < (infection-chance * 1.3) [newinfection spreader "school"]
        ]
      ]
    ]

    ;; Every day an infected person has the chance to infect all their household members. Even if the agent is isolating
    if any? household-neighbors  [
      let hh-infection-chance infection-chance

      ;; if the person is isolating the people in the household will try to stay away...
      if isolated? [set hh-infection-chance infection-chance * 0.7]

      ask household-neighbors [
        if (not infected?) and (not cured?) and (not [removed?] of household-with spreader) and
        infectious? and random 100 < hh-infection-chance [newinfection spreader "household"]
      ]
    ]
  ]

  ;; Every week we visit granpa and risk infecting him
  if (ticks mod 7 = 0 or ticks mod 6 = 0) and any? my-relations [
    ask one-of relation-neighbors [
      if not [removed?] of relation-with spreader [
        ask spreader [set visited-relations-this-week (turtle-set myself)]
        if (not cured?) and infectious? and random 100 < infection-chance [newinfection spreader "relations"]
      ]
    ]
  ]

  ;; Infected agents will also infect someone at random. The probability is 1/10 of the normal infection-chance
  ;; If we're not using the network this is the sole mode of contact.
  ;; Here, again, if both parties have the app a link is created to keep track of the meeting
  if random-passersby != nobody [
    ask random-passersby [
      if (not infected?) and (not aware?) and (not isolated?) [
        if has-app? and [has-app?] of spreader [add-contact spreader]
        if infectious? and (not cured?) and random 100 < (infection-chance * 0.1) [newinfection spreader "random"]
      ]
    ]
  ]
end

to add-contact [infected-agent]
  create-tracing-with infected-agent [set day ticks]
end

to newinfection [spreader origin]
  set infected? true
  set symptomatic? false
  set severe-symptoms? false
  set aware? false
  set nb-infected (nb-infected + 1)
  set infected-by spreader
  ask spreader [set spreading-to spreading-to + 1]
  table:put counters origin (table:get counters origin + 1)
end

;;  ========= Interventions =============================

to lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Locking down!")
  ]
  set lockdown? true
  ask friendships [set removed? true]
  ask relations [set removed? true]
  close-schools
end

to remove-lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Removing lockdown!")
  ]
  set lockdown? false
  ask turtles with [not isolated?] [ask my-links [set removed? false]]
  set schools-open? true
end

to close-schools
  ask classes [set removed? true]
  set schools-open? false
end

to get-tested
  if not tested-today? [  ;; I'm only doing this because there are some who for some reason test more times on the same day and I can't catch them...
    ;show (word "  day " ticks ": tested-today?: " tested-today? " - aware?: " aware? "  - now getting tested")
    set tested-today? true
    set tests-remaining tests-remaining - 1
    set tests-performed tests-performed + 1
   ; if tests-remaining = 0 and behaviorspace-run-number = 0 [output-print (word "Day " ticks ": tests finished")]
    if infected? [
      set aware? true
      isolate
      let needtesting household-neighbors with [tested-today? = false and aware? = false]
      if visited-relations-this-week != nobody and should-test? visited-relations-this-week [
        set needtesting (turtle-set needtesting visited-relations-this-week)
      ]
      ask needtesting [
        ifelse tests-remaining > 0 [get-tested] [ if not isolated? [maybe-isolate ]]
      ]
      if has-app? [
        ask tracing-neighbors with [should-test? self] [
          ifelse tests-remaining > 0
          [ get-tested ]
          [ if not isolated? [maybe-isolate ]]
        ]
      ]
    ]
  ]
end

;; =======================================================

to-report impossible-run
  if tests-per-100-people = 0 and pct-with-tracing-app > 0 [report true]
  report false
end
@#$#@#$#@
GRAPHICS-WINDOW
415
830
904
1320
-1
-1
2.393035
1
10
1
1
1
0
0
0
1
-100
100
-100
100
1
1
1
day
30.0

BUTTON
240
225
320
258
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
320
225
385
258
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
155
65
355
98
average-isolation-tendency
average-isolation-tendency
0
100
70.0
5
1
NIL
HORIZONTAL

PLOT
5
535
411
727
Populations
days
# people
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot count turtles with [ infected? ] "
"Dead" 1.0 0 -16777216 true "" "plot count turtles with [dead?] "
"Hospitalized" 1.0 0 -955883 true "" "plot in-hospital"
"Self-Isolating" 1.0 0 -13791810 true "" "plot count turtles with [isolated?]"

PLOT
3
734
412
902
Infection and Recovery Rates
days
rate
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"Infection Rate" 1.0 0 -2674135 true "" "plot (beta-n * nb-infected-previous)"
"Recovery Rate" 1.0 0 -10899396 true "" "plot (gamma * nb-infected-previous)"

SLIDER
10
30
155
63
infection-chance
infection-chance
0
50
4.5
0.1
1
%
HORIZONTAL

MONITOR
15
305
85
350
R0
r0
2
1
11

PLOT
7
355
409
530
Cumulative Infected and Recovered
days
% total pop.
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"% infected" 1.0 0 -2674135 true "" "plot (((count turtles with [ cured? ] + count turtles with [ infected? ]) / N-people) * 100)"
"% recovered" 1.0 0 -9276814 true "" "plot ((count turtles with [ cured? ] / N-people) * 100)"

SLIDER
10
180
205
213
initial-links-per-age-group
initial-links-per-age-group
0
100
25.0
1
1
NIL
HORIZONTAL

PLOT
420
600
710
818
Degree distribution (log-log)
log(degree)
log(#of nodes)
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "let max-degree max [count friendship-neighbors] of turtles with [age > 12]\n;; for this plot, the axes are logarithmic, so we can't\n;; use \"histogram-from\"; we have to plot the points\n;; ourselves one at a time\nplot-pen-reset  ;; erase what we plotted before\n;; the way we create the network there is never a zero degree node,\n;; so start plotting at degree one\nlet degree 1\nwhile [degree <= max-degree] [\n  let matches turtles with [age > 12 and count friendship-neighbors = degree]\n  if any? matches\n    [ plotxy log degree 10\n             log (count matches) 10 ]\n  set degree degree + 1\n]"

PLOT
718
599
1008
819
Degree distribution
NIL
NIL
1.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count friendship-neighbors] of turtles with [age > 12]\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-degree + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [count friendship-neighbors] of turtles with [age > 12]"

SWITCH
10
215
142
248
show-layout
show-layout
1
1
-1000

BUTTON
840
260
935
293
LOCKDOWN
lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

TEXTBOX
544
572
900
599
====== \"Friendship\" network ======
20
0.0
1

MONITOR
185
305
253
350
Deaths
count turtles with [dead?]
0
1
11

SWITCH
10
145
140
178
use-network?
use-network?
0
1
-1000

SWITCH
920
295
1105
328
lockdown-at-first-death
lockdown-at-first-death
1
1
-1000

TEXTBOX
145
220
220
255
(Very slow Don't use)
12
0.0
1

SLIDER
10
65
155
98
incubation-days
incubation-days
0
10
5.0
1
1
NIL
HORIZONTAL

OUTPUT
405
10
1140
255
16

SLIDER
155
30
300
63
initially-infected
initially-infected
0
5
0.9
0.1
1
%
HORIZONTAL

PLOT
420
345
750
535
Infections per agent
# agents infected
# agents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-spreading max [spreading-to] of turtles\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-spreading + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [spreading-to] of turtles with [spreading-to > 0]"

SLIDER
420
295
594
328
pct-with-tracing-app
pct-with-tracing-app
0
100
0.0
1
1
%
HORIZONTAL

SLIDER
600
295
775
328
tests-per-100-people
tests-per-100-people
0
20
4.0
0.01
1
NIL
HORIZONTAL

BUTTON
10
255
132
288
Export network
export-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
240
155
385
188
use-seed?
use-seed?
1
1
-1000

SWITCH
240
190
385
223
use-existing-nw?
use-existing-nw?
0
1
-1000

MONITOR
270
305
340
350
Available
tests-remaining
0
1
11

MONITOR
90
305
167
350
current R0
mean ([spreading-to] of turtles with [cured-since >= (ticks - 7)])
4
1
11

PLOT
755
345
1105
550
Sources of infection
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Household" 1.0 0 -16777216 true "" "plot table:get counters \"household\""
"Friends" 1.0 0 -13791810 true "" "plot table:get counters \"friends\""
"School" 1.0 0 -2674135 true "" "plot table:get counters \"school\""
"Strangers" 1.0 0 -955883 true "" "plot table:get counters \"random\""
"Relations" 1.0 0 -7500403 true "" "plot table:get counters \"relations\""

SWITCH
780
295
915
328
schools-open?
schools-open?
0
1
-1000

TEXTBOX
10
10
385
30
Disease Configuration (see also DiseaseConfig.nls)
14
0.0
1

TEXTBOX
10
125
180
156
Network configuration
14
0.0
1

TEXTBOX
280
130
440
161
Runtime config
14
0.0
1

TEXTBOX
460
265
855
291
============| MITIGATIONS |===========
14
0.0
1

BUTTON
940
260
1097
293
REMOVE LOCKDOWN
remove-lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
345
305
415
350
Performed
tests-performed
1
1
11

TEXTBOX
295
290
395
308
Tests ======
11
0.0
1

@#$#@#$#@
# covid19 in small communities

A tentative multi-level network based SEIR model of the progression of the COVID19 infection.

## A preliminary warning

This is a simulation with random events and plausible but (partially) unverified assumptions, please do not take it a a sure forecasting machine, it is a reasoning machine, a sort of very complex “what if” mental experiment.

## The model

### Agents

The population is imported in the model upon setup from the file vo.csv. Agent attributes are _age_ and _marital status_ (source: http://demo.istat.it/pop2019/index3.html). Any population can be imported from a csv structured as follows:

``age,singleMales,marriedMales,divorcedMales,widowesMales,singleFemales,marriedFemales,divorcedFemales,widowedFemales``

### Networks

Agents in the model belong to three intertwined networks: 'household', 'relation' and 'friendship' 

A **household** structure is created as follows: married males and females are linked together on the basis of age distance, single people below the age of 28 are assumed to live at home with one or two parents and siblings. Single people above the age of 26 are assumed to live on their own, a certain proportion cohabiting. Links of type 'household' are built among these people.

A **friendship** network is created among all agents > 14 y.o. based on the *preferential attachment* principle, so that a scale-free network is produced. Friendships are skewed towards people of the same age group.

A **relation** network links people who are related but don't live in the same household (i.e. grandparents).

### Infection

The infection is assumed to predominantly follow social links. People in an infected agent's social network can be infected. When someone becomes infected, after a period of incubation, she becomes infective starts infecting others.

The progression of the disease is based on data from China and Italy. Agents have a probability of developing symptoms after incubation, based on their age, another probability of worsening and another of dying. These are set up in DiseaseConfig.nls

![Progression of the infection](https://raw.githubusercontent.com/harrykipper/covid/master/infection.png)

### Lockdown

The model implements lockdown policies based on the response of nearly all European countries. In a lockdown all friendship links are dropped (= no one can be infected through their friends) and schools are closed. Crucially, agents are assumed to be segregating at home, therefore household members are still somewhat exposed to the infection.

### Contact tracing

The model also simulates a proposed contact tracing strategy for the "second phase" of epidemic control: an opt-in smartphone app. Upon model initialization a certain proportion of agents are given the "app". If an agent with the app tests positive for COVID19 all other agents who have come into contact with her in the previous 10 days, and also have the app, are notified and have the option to self-segregate as a precaution.
In case tests are unavailable, the app is alerts contacts when an agent is experiencing symptoms, so they have the choice of self isolating.

## Model configuration

The model can be configured changing the transition probabilities and timings at the beginning of the Code section in Netlogo and the following parameters in Netlogo's interface:

**Disease configuration**

* *infection-chance*  Daily probability of infecting a subset of one infected person's network 
* *initially-infected* Number of agents infected at simulation day 0
* *incubation-days* Days before an infected agent becomes infectious and may show symptoms 
* *average-isolation-tendency* Probability of self-isolating after displaying symptoms   

**Network related**

* *use-network?* If false contagion happens randomly                          
* *initial-links-per-age-group* No. of random friendship links within each group upon initialization 
* *show-layout?* Display the whole social network stricture. **WARNING: VERY SLOW** 
* *lockdown-at-first-death* Implement a full lockdown upon the first reported death (as happened in Vo' Euganeo) 

**Mitigtions**

* *pct-with-tracing-app* Percentage of the population carrying the contact-tracing app
* *tests-per-100-people* Number of tests available per week as proportion of the population
* *schools-open?* Whether kids go to school each morning

**Runtime config**

* *use-seed* The simulation uses a fixed random seed
* *use-existing-nw* Use a pre-generated social network instead of creating one at setup (much faster)

## What to do with this

The model is useful to show the progression of the infection in a small community and appreciate the difference in infections and casualties with and without social distancing/lockdown measures, and to test the effectiveness of infection mitigation strategies such as contact tracing apps.

The model also shows that, when we assume that the viral transmission runs predominantly through one's social network, the dynamic of the infection is different from that emerging under the assumption of most SEIR models of an equal probability of everyone infecting everyone else.

The model is easy to adapt to test different levels of infectiousness and different proportions of people becoming symptomatic and severely ill.


## The Vo' Euganeo case

The first official Italian COVID19 death was a 78 year old resident of the town of Vo' Euganeo, in the province of Padua, on February 22. Immediately afterwards, a lockdown of the whole town was ordered and 85% of the whole population of 3300 was tested. Nearly 3% was found to be carrying the Coronavirus (https://www.scribd.com/document/450608044/Coronavirus-Regione-Veneto-Azienda-Zero-pdf). Eighteen days later a second death was recorded in the town, a 68 year old, who was a friend of the first victim.

## RELATED MODELS

epiDEM basic, HIV, Virus, Virus on a Network, Preferential Attachment are related models.

## CREDITS AND REFERENCES

The preferential attachment bit of the model is based on:

* Albert-László Barabási. Linked: The New Science of Networks, Perseus Publishing, Cambridge, Massachusetts, pages 79-92.

The model includes code adapted from the following models:

* Wilensky, U. (2005).  NetLogo Preferential Attachment model.  http://ccl.northwestern.edu/netlogo/models/PreferentialAttachment.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
* Yang, C. and Wilensky, U. (2011).  NetLogo epiDEM Travel and Control model.  http://ccl.northwestern.edu/netlogo/models/epiDEMTravelandControl.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person lefty
false
0
Circle -7500403 true true 170 5 80
Polygon -7500403 true true 165 90 180 195 150 285 165 300 195 300 210 225 225 300 255 300 270 285 240 195 255 90
Rectangle -7500403 true true 187 79 232 94
Polygon -7500403 true true 255 90 300 150 285 180 225 105
Polygon -7500403 true true 165 90 120 150 135 180 195 105

person righty
false
0
Circle -7500403 true true 50 5 80
Polygon -7500403 true true 45 90 60 195 30 285 45 300 75 300 90 225 105 300 135 300 150 285 120 195 135 90
Rectangle -7500403 true true 67 79 112 94
Polygon -7500403 true true 135 90 180 150 165 180 105 105
Polygon -7500403 true true 45 90 0 150 15 180 75 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="35"/>
      <value value="50"/>
      <value value="75"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="35"/>
      <value value="50"/>
      <value value="75"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="contact" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="0.6"/>
      <value value="1"/>
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="contact_seeded" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="0.6"/>
      <value value="1"/>
      <value value="1.6"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="contact_unseeded" repetitions="20" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="4.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="0.6"/>
      <value value="1.6"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
