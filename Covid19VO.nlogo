__includes [ "DiseaseConfig.nls" "output.nls" "SocialNetwork.nls" "layout.nls"]

extensions [csv]

undirected-link-breed [households household]
undirected-link-breed [relations relation]
undirected-link-breed [friendships friendship]
undirected-link-breed [contacts contact]     ;; The contact tracing app

globals
[
  N-people
  use-existing-nw?
  tests-remaining      ;; Counter for tests
  tests-performed      ;; How many people were tested
  recovery-chance      ;; Daily probability of recovering after the course of the sickness is complete (= recovery-time is reached)
  nb-infected-previous ;; Number of infected people at the previous tick
  in-hospital          ;; Number of people currently in hospital
  hospital-beds        ;; Number of places in the hospital
  contact-tracing      ;; If true a contact tracing app exists
  angle                ;; Heading for individuals
  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population
  lockdown?            ;; If true we are in a state of lockdown
]

turtles-own
[
  sex
  age
  status               ;; Marital status
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
  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine when symptomatic.

  susceptible?         ;; Tracks whether the person was initially susceptible
  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-recovered         ;; Number of recovered people at the end of the tick

  has-app?             ;; If true the agent carries the contact-tracing app
  tested-today?        ;; The agent
  aware?
]

links-own [mean-age removed?]
households-own [ltype]  ; ltype 0 is a spouse; ltype 1 is offspring/sibling
contacts-own [day]

;; ===========================================================================
;;;
;;; SETUP
;;;
;; ==========================================================================

to setup
  if use-seed? [random-seed 1790941519] ;-1228151657]
  clear-all

  if impossible-run [
    reset-ticks
    stop
  ]
  set-default-shape turtles "circle"
  ifelse pct-with-tracing-app > 0 [set contact-tracing true][set contact-tracing false]

  read-agents
  set N-people count turtles

  set tests-remaining round ((tests-per-100-people / 100) * N-People)

  if use-network? [
    ifelse use-existing-nw? = true
    [import-network]
    [
      create-hh
      make-initial-links
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

  reset-ticks

  infect-initial-agents

  ;; When someone has traversed the whole course of the illness there's a daily chance of recovery
  ;; of 30%. Meaning that in 3/4 days the agent fully recovers
  set recovery-chance 35
end

to infect-initial-agents
  ask n-of initially-infected turtles with [age >= 25][
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
  set spreading-to []
  set infected-by nobody
  if random 100 < pct-with-tracing-app [set has-app? true]
end

to read-agents
  let row 0
  foreach csv:from-file "vo.csv" [ag ->
    let i 1
    if row > 0 [
      while [i < length ag][
        crt item i ag [
          set age item 0 ag + 1 ;; Data are from 2019, everyone is one year older now..
          ; show (word "DEBUG: Creating agents of age " item 0 ag)
          ifelse i < 5 [set sex "M"][set sex "F"]
          ifelse i = 1 or i = 5 [set status 0][
            ifelse i = 2 or i = 6 [set status 1][
              ifelse i = 3 or i = 7 [set status 2][
                ifelse i = 4 or i = 8 [set status 3][set status 4]
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

to assign-tendency ;; Turtle procedure
  set isolation-tendency random-normal average-isolation-tendency average-isolation-tendency / 4
  set recovery-time 1 + round (random-normal (average-recovery-time age) (average-recovery-time age / 4))
  set prob-symptoms probability-of-showing-symptoms age * gender-discount sex
  set symptom-time round random-normal incubation-days 0.5

  ;; Make sure recovery-time lies between 0 and 2x average-recovery-time
  if recovery-time > (average-recovery-time age) * 2 [ set recovery-time (average-recovery-time age) ]
  if recovery-time < 0 [ set recovery-time 4 ]

  ;; Similarly for isolation and hospital going tendencies
  if isolation-tendency > average-isolation-tendency * 2 [ set isolation-tendency average-isolation-tendency ]
  if isolation-tendency < 0 [ set isolation-tendency 0 ]
end

to-report gender-discount [gender]
  if gender = "F" [report 0.8]
  report 1
end

;;;
;;; GO PROCEDURES
;;;

to go
  if behaviorspace-run-number != 0 and ticks = 0 [
    if impossible-run [stop]
  ]

  if all? turtles [ not infected? ][
    ifelse behaviorspace-run-number = 0
    [print-final-summary]
    [save-output]
    stop
  ]

  ask turtles [
    clear-count
    set tested-today? false
  ]

  if contact-tracing = true [ask contacts with [day <= (ticks - 14)][die]]

  ask turtles with [isolated?] [
    set days-isolated days-isolated + 1
    if not symptomatic? and days-isolated = 14 [unisolate]
  ]

  ;; If you're in hospital you don't infect anyone. If you're isolated you can infect members of your household
  ask turtles with [infected? and not hospitalized? and infection-length >= incubation-days] [ infect ]

  ask turtles with [not hospitalized? and infected? and severe-symptoms?] [hospitalize]

  ask turtles with [infected?] [
    set infection-length infection-length + 1

    ;; Progression of the infection
    if severe-symptoms? and infection-length = recovery-time [maybe-die]
    if symptomatic? and not severe-symptoms? and infection-length = recovery-time [maybe-worsen]
    if not symptomatic? and infection-length = symptom-time [maybe-show-symptoms]

    ;; It takes time to get tested and receive the response
    if symptomatic? and not tested-today? and not aware? and infection-length = 4 [
      ifelse tests-remaining > 0
        [get-tested]
        [if isolated? = false and random 100 < isolation-tendency [
        isolate
        ask household-neighbors [if isolated? = false and random 100 < isolation-tendency [isolate]]
        ]
      ]
    ]
    maybe-recover
  ]

  ask turtles with [(isolated? or hospitalized?) and cured?] [unisolate]

  ask turtles
    [ assign-color
      calculate-r0 ]

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
  if probability-of-worsening age * gender-discount sex > random 100 [
    set severe-symptoms? true
    set recovery-time round (infection-length + random-normal 7 2 )
  ]
end

to maybe-die
  ifelse hospitalized?
  [if probability-of-dying age > random 100 [kill-agent]]
  [if (probability-of-dying age) * 1.5 > random 100 [kill-agent]]  ; no hospital bed means a dire fate
end

to maybe-recover
  ;; If people have been infected for more than recovery-time
  ;; it means they have survived and there is a chance for recovery.
  if infection-length > recovery-time [
    if random-float 100 < recovery-chance [
      set infected? false
      set cured? true
      if isolated? [unisolate]
      set nb-recovered (nb-recovered + 1)
      if hospitalized? [
        set in-hospital in-hospital - 1
        unisolate
      ]
    ]
  ]
end

to kill-agent
  ask my-friendships [die]
  ask my-households [die]
  ask my-relations [die]
  set dead? true
  if count turtles with [dead?] = 1 [
    if lockdown-at-first-death [lockdown]
    if behaviorspace-run-number = 0 [
      output-print (word "Epidemic day " ticks ": death number 1. Age: " age "; gender: " sex)
      output-print (word "Duration of agent's infection: " symptom-time " days incubation + "
        infection-length " days of illness")
      print-current-summary
    ]
  ]
end

;; ===============================================================================

;; When the agent is isolating all friendhips and relations are frozen.
;; Crucially household links stay in place, as it is assumed that one isolates at home
to isolate ;; turtle procedure
  set isolated? true
  ask my-friendships [set removed? true]
  ask my-relations [set removed? true]
end

;; After unisolating, links return in place
to unisolate  ;; turtle procedure
  set isolated? false
  set hospitalized? false
  ask my-links with [removed? = true][set removed? false]
end

;; To hospitalize, remove all links.
to hospitalize ;; turtle procedure
  set hospitalized? true
  set in-hospital in-hospital + 1

  ;; We assume that hospitals always have tests. If I end up in hospital, the app will tell people.
  ask contact-neighbors with [tested-today? = false and aware? = false] [
    ifelse tests-remaining > 0
    [get-tested ]
    [
      let tendency isolation-tendency
      if not symptomatic? [set tendency tendency * 0.7]
      if random 100 < isolation-tendency [isolate]
    ]
  ]

  ask my-links [set removed? true]
  set isolated? true
  set pcolor black
  if show-layout [
    move-to patch (max-pxcor / 2) 0
    ask my-links [set removed? true]
    set pcolor white
  ]
end

to get-tested
  if not tested-today? [    ;; I'm only doing this because there are some who for some reason test more times on the same day and I can't catch them...
    ;show (word "  day " ticks ": tested-today?: " tested-today? " - aware?: " aware? "  - now getting tested")
    set tested-today? true
    set tests-remaining tests-remaining - 1
    if infected? [
      set aware? true
      isolate
      ask household-neighbors with [tested-today? = false and aware? = false] [
        ifelse tests-remaining > 0 [get-tested] [isolate]
      ]
      if has-app? [
        ask contact-neighbors with [tested-today? = false and aware? = false] [
          ifelse tests-remaining > 0
          [ get-tested ]
          [
            let tendency isolation-tendency
            if not symptomatic? [set tendency tendency * 0.7]
            if random 100 < tendency [isolate]]
        ]
      ]
    ]
  ]
end

to lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Now locking down!")
  ]
  set lockdown? true
  ask friendships [set removed? true]
  ask relations [set removed? true]
end

;=====================================================================================

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible friends and family.

to infect  ;; turtle procedure
  let spreader self
  let proportion 100
  let all-contacts other turtles
  let random-passerby nobody

  if use-network? [
    set proportion 8
    set all-contacts friendship-neighbors
    if isolated? = false and lockdown? = false [set random-passerby n-of random 5 other turtles]
  ]

  if count all-contacts > 0 [
    ask n-of (1 + random round (count all-contacts / proportion)) all-contacts [
      ifelse use-network?

      ;;; Every day the agent meets a certain fraction of her friends.
      ;;; If the agent has the contact tracing app, a link is created
      ;;; between her and those friends who also have the app.
      ;;; With probability infection-chance the agent the infects the susceptible friends who she is meeting.

      [if not infected? and not cured? and [removed?] of friendship-with spreader = false [
        if has-app? and [has-app?] of spreader [
          ;show (word "I just met an infected person! (" spreader "). The app will tell me when he knows!")
          add-contact spreader]
        if random 100 < infection-chance [newinfection spreader]]]
      [if not infected? and not cured? and not isolated? and not [isolated?] of spreader [
        if has-app? and [has-app?] of spreader [add-contact spreader]
        if random 100 < infection-chance [newinfection spreader]]
      ]
    ]
  ]

  ;; Every day an infected person has the chance to infect all their household members.
  ;; Even if the agent is isolating.
  if any? household-neighbors  [
    let hh-infection-chance infection-chance

    ;; if the person is isolating the people in the household will try to stay away...
    if isolated? [set hh-infection-chance infection-chance * 0.8]

    ask household-neighbors [
      if not infected? and not cured? and not [removed?] of household-with spreader [
       ; if has-app? and [has-app?] of spreader [add-contact spreader]
        if random 100 < hh-infection-chance [newinfection spreader]
      ]
    ]
  ]

  ;; Infected agents will also infect someone at random.
  ;; Here, again, if both parties have the app a link is created to keep track of the meeting
  if random-passerby != nobody [
    ask random-passerby [
      if not infected? and not cured? and not isolated? [
        if has-app? and [has-app?] of spreader [add-contact spreader]
        if random 100 < infection-chance [newinfection spreader]]
    ]
  ]
end

to add-contact [infected-agent]
  create-contact-with infected-agent [set day ticks]
end

to newinfection [spreader]
  set infected? true
  set symptomatic? false
  set severe-symptoms? false
  set nb-infected (nb-infected + 1)
  set infected-by spreader
  ask spreader [set spreading-to lput myself spreading-to]
end


to-report impossible-run
  if tests-per-100-people = 0 and pct-with-tracing-app > 0 [report true]
  report false
end
@#$#@#$#@
GRAPHICS-WINDOW
423
10
1319
907
-1
-1
4.42
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
5
161
88
194
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
89
199
154
232
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
193
10
413
43
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
11
424
417
616
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
"Susceptible" 1.0 0 -10899396 true "" "plot count turtles with [ not infected? and not cured? ] "
"Recovered" 1.0 0 -7500403 true "" "plot count turtles with [ cured? ] "
"Dead" 1.0 0 -16777216 true "" "plot count turtles with [dead?] "
"Hospitalized" 1.0 0 -955883 true "" "plot in-hospital"
"Self-Isolating" 1.0 0 -6459832 true "" "plot count turtles with [isolated?]"

PLOT
9
623
418
791
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
7
10
187
43
infection-chance
infection-chance
10
100
15.0
5
1
NIL
HORIZONTAL

MONITOR
424
997
494
1042
R0
r0
2
1
11

PLOT
13
244
415
419
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
193
47
410
80
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
0
1083
290
1301
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
298
1082
588
1302
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
215
125
347
158
show-layout
show-layout
1
1
-1000

BUTTON
156
198
249
232
LOCKDOWN!
lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
124
1055
480
1082
====== \"Friendship\" network ======
20
0.0
1

MONITOR
499
997
567
1042
Deaths
count turtles with [dead?]
0
1
11

SWITCH
235
85
379
118
use-network?
use-network?
0
1
-1000

SWITCH
5
125
209
158
lockdown-at-first-death
lockdown-at-first-death
1
1
-1000

TEXTBOX
353
137
423
155
(Very slow!)
12
0.0
1

SLIDER
5
50
185
83
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
605
920
1320
1308
30

SLIDER
5
85
227
118
initially-infected
initially-infected
0
10
2.0
1
1
NIL
HORIZONTAL

PLOT
10
794
416
1048
Spreaders
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
"default" 1.0 1 -16777216 true "" "let max-spreading max [length spreading-to] of turtles\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-spreading + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [length spreading-to] of turtles with [length spreading-to > 0]"

SLIDER
423
915
597
948
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
422
955
597
988
tests-per-100-people
tests-per-100-people
0
400
10.0
1
1
NIL
HORIZONTAL

BUTTON
7
198
87
231
Export NW
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
90
162
202
195
use-seed?
use-seed?
1
1
-1000

SWITCH
204
162
353
195
use-existing-nw
use-existing-nw
1
1
-1000

MONITOR
361
171
419
228
Tests
tests-remaining
0
1
14

@#$#@#$#@
# covid19 in Vo' Euganeo (or anywhere else)

A tentative multi-level network based SIR model of the progression of the COVID19 infection.

## The model

### Agents

The population is imported in the model upon setup from the file vo.csv. Agent attributes are _age_ and _marital status_ (source: http://demo.istat.it/pop2019/index3.html). Any population can be imported from a csv structured as follows:

``age,singleMales,marriedMales,divorcedMales,widowesMales,singleFemales,marriedFemales,divorcedFemales,widowedFemales``

### Networks

Agents in the model belong to three intertwined networks: 'household', 'relation' and 'friendship' 

A **household** structure is created as follows: married males and females are linked together on the basis of age distance, single people below the age of 26 are assumed to live at home with one or two parents and siblings. Single people above the age of 26 are assumed to live on their own, a certain proportion cohabiting. Links of type 'household' are built among these people.

A **friendship** network is created among all agents > 12 y.o. based on the *preferential attachment* principle, so that a scale-free network is produced. Friendships are skewed towards people of the same age group.

*(TODO*) A 'relation' network links people who are related but don't live in the same household

### Infection

The infection is assumed to follow social links. Only people in an infected agent's social network can be infected. When someone becomes infected, after a period of incubation, she starts infecting people 

The progression of the disease is based on data from China and Italy. Agents have a probability of developing symptoms after incubation, based on their age, another probability of worsening and another of dying. These are at the top of the 'Code' section in Netlogo.

### Lockdown

The model implements lockdown policies based on the response of nearly all European countries. In a lockdown all _friendship_ links are dropped (= no one can be infected through their friends). Crucially, agents are assumed to be segregating at home, therefore household members are still susceptible to the infection.

### Contact tracing 

The model also tries to simulate a proposed contact tracing strategy for the "second phase" of epidemic control: an opt-in smartphone app. Upon model initialization a certain proportion of agents are given the "app". If an agent with the app tests positive for COVID19 all other agents who have come into contact with her, and also have the app, are notified and have the option to self-segregate as a precaution.

## Model configuration

The model can be configured changing the transition probabilities and timings at the beginning of the Code section in Netlogo and the following parameters in Netlogo's interface:

* *infection-chance*  Daily probability of infecting a subset of one infected person's network 
* *initially-infected* Number of agents infected at simulation day 0
* *incubation-days* Days before an infected agent becomes infectious and may show symptoms 
* *average-isolation-tendency* Probability of self-isolating after displaying symptoms      
* *initial-links-per-age-group* No. of random friendship links within each group upon initialization 
* *use-network?* If false contagion happens randomly                          
* *show-layout?* Display the whole social network stricture. **WARNING: VERY SLOW** 
* *lockdown-at-first-death* Implement a full lockdown upon the first reported death (as happened in Vo' Euganeo) 
* *pct-with-tracing-app* Percentage of the population carrying the contact-tracing app |
* *tests-per-100-people* Probability that a symptomatic individual is tested for COVID19

## What to do with this

The model is useful to show the progression of the infection in a small community and appreciate the difference in infections and casualties with and without social distancing and lockdown measures.
It also shows that, when we assume that the viral transmission runs predominantly through one's social network, the dynamic of the infection is different from that emerging under the assumption of most SEIR models of an equal probability of everyone infecting everyone else.

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
  <experiment name="contact" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
      <value value="120"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="true"/>
      <value value="false"/>
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
