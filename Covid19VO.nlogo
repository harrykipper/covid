extensions [csv]

undirected-link-breed [spouses spouse]
undirected-link-breed [households household]
undirected-link-breed [relations relation]
undirected-link-breed [friendships friendship]

globals
[
  N-people
  recovery-chance      ;; Daily probability of recovering after the course of the sickness is complete (= recovery-time is reached)
  nb-infected-previous ;; Number of infected people at the previous tick
  in-hospital          ;; Number of people currently in hospital
  hospital-beds        ;; Number of places in the hospital
  angle                ;; Heading for individuals
  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population
]

turtles-own
[
  sex
  age
  status               ;; marital status
  infected?            ;; If true, the person is infected.
  cured?               ;; If true, the person has lived through an infection. They cannot be re-infected.
  symptomatic?         ;; If true, the person is showing symptoms of infection
  severe-symptoms?     ;; If true, the person is showing severe symptoms
  isolated?            ;; If true, the person is isolated, unable to infect anyone.
  hospitalized?        ;; If true, the person is hospitalized.
  dead?                ;; If true, the person is... you know..
  infected-by          ;; ID of agent who infected me
  spreading-to         ;; ID of agents infected by me

  infection-length     ;; How long the person has been infected.
  recovery-time        ;; Time (in days) it takes before the person has a chance to recover from the infection
  symptom-time         ;; Time (in days) it takes before the person shows symptoms
  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine when symptomatic.

  susceptible?         ;; Tracks whether the person was initially susceptible
  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-recovered         ;; Number of recovered people at the end of the tick
]

links-own [mean-age removed?]


;; ===========================================================================
;;       Model configuration  --- TRANSITION PROBABILITIES and TIMIGS
;;
;;    Change the following values to implement a different disease course
;;============================================================================


to-report average-recovery-time [agent-age]
  ;; Infected agents recover, on average, after these many days since being infected
  report (ifelse-value
    agent-age < 40 [7]
    agent-age < 50 [10]
    agent-age < 60 [12]
    [16]
    )
end

;; The three parameters below obviously interact.
;; The probability of someone dying of covid is:
;; probability-of-showing-syptoms * probability-of-worsening * probability-of-dying
;; For someone between 30 and 40 this is currently 0.25 * 0.05 * 0.05 = 0.000625 or 0.06%

to-report probability-of-showing-symptoms [agent-age]
  ;; When the incubation period ('incubation-days' in main interface) is over
  ;; the agent has the following probability of developing the symptoms of COVID-19.
  ;; If the person is showing symptoms, it'll take 7 more days to recover.
  report (ifelse-value
    agent-age < 30 [15]
    agent-age < 40 [25]
    agent-age <= 50 [45]
    agent-age < 60 [75]
    [85]
  )
end

to-report probability-of-worsening [agent-age]
  ;; After 10 days with symptoms the agent has the following probability of
  ;; worsening and needing hospital care.
  report (ifelse-value
    agent-age < 40 [5]
    agent-age < 50 [10]
    agent-age < 60 [15]
    [25]
  )
end

to-report probability-of-dying [agent-age]
  ;; After 10 days in the hospital the agent has the following probability of dying
  report (ifelse-value
    agent-age < 40 [5]
    agent-age < 50 [10]
    agent-age < 60 [18]
    [25]
  )
end


;; END of model configuration  ==================================================


;; ===========================================================================
;;;
;;; SETUP
;;;
;; ==========================================================================

to setup
  clear-all
  set-default-shape turtles "circle"

  read-agents
  set N-people count turtles

  if use-network? [
    create-hh
    make-initial-links
    create-friendships
    ask links [set removed? false]
    if show-layout [
      resize-nodes
      repeat 50 [layout]]
  ]

  reset-ticks

  ask n-of initially-infected turtles with [age >= 25][
    set infected? true
    set susceptible? false
  ]

  ;; When someone has traversed the whole course of the illness there's a daily chance of recovery
  ;; of 30%. Meaning that in 3/4 days the person recovers
  set recovery-chance 30
end

to read-agents
  let row 0
  foreach csv:from-file "vo.csv" [ag ->
    let i 1
    if row > 0 [
      while [i < length ag][
        crt item i ag [

          set cured? false
          set isolated? false
          set hospitalized? false
          set infected? false
          set susceptible? true
          set symptomatic? false
          set severe-symptoms? false
          set dead? false
          set age item 0 ag + 1 ;; Data are from 2019, everyone is one year older now...
          set spreading-to []
          set infected-by nobody

          ; show (word "DEBUG: Creating agents of age " item 0 ag)
          ifelse i < 5 [set sex "M"][set sex "F"]
          ifelse i = 1 or i = 5 [set status 0][
            ifelse i = 2 or i = 6 [set status 1][
              ifelse i = 3 or i = 7 [set status 2][
                ifelse i = 4 or i = 8 [set status 3][set status 4]
              ]
            ]
          ]
          assign-tendency
        ]
        set i i + 1
      ]
    ]
    set row row + 1
  ]
end


;; ==========================================================
;;                     SOCIAL NETWORK
;; ==========================================================

to create-hh
  create-marriages
  if show-layout [repeat 50 [layout]]
  attach-children
  ;repeat count turtles with [status = 0] / 2 [layout]
  if show-layout [repeat 50 [layout]]
end

to create-marriages
  ask turtles with [sex = "F" and status = 1][
    let pretendenti turtles with [
      sex = "M" and
      status = 1 and
      count my-spouses = 0
    ]
    let marito min-one-of pretendenti [abs (age - [age] of myself)]
    create-spouse-with marito
    if show-layout [
      move-to marito
      fd 8
    ]
  ]

  let zitelle turtles with [
    age >= 28 and
    status = 0 and
    sex = "F"]

  ask n-of (count zitelle / 2) zitelle [
    let pretendenti turtles with [
      sex = "M" and
      status = 0 and
      count my-spouses = 0
    ]
    let marito min-one-of pretendenti [abs (age - [age] of myself)]
    create-spouse-with marito
  ]
end

to attach-children
  ask turtles with [
    age < 28 and
    status = 0
  ][
    let age-interval-min age + 24
    let age-interval-max age + 36
    let thekid self
    ask one-of turtles with [
      status != 0 and
      sex = "M" and
      age <= age-interval-max and age >= age-interval-min
    ]
    [
      if any? my-spouses [ask spouse-neighbors [create-household-with thekid]]
      ifelse any? my-households [
        ask my-households [ask both-ends [create-household-with thekid]]
      ][create-household-with thekid]
    ]
  ]
  if show-layout [layout]
end

to create-relations
  ; not there yet ;-)
end

to create-friendships
  ask turtles with [age >= 12][
    repeat 5 + random 10 [create-friendship-with find-partner]
  ]
  if show-layout [layout]
end

;=====================================================================================
;=====================================================================================


to assign-tendency ;; Turtle procedure
  set isolation-tendency random-normal average-isolation-tendency average-isolation-tendency / 4
  set recovery-time 1 + round (random-normal (average-recovery-time age) (average-recovery-time age / 4))
  set prob-symptoms probability-of-showing-symptoms age * gender-discount sex
  set symptom-time round random-normal incubation-days 1

  ;; Make sure recovery-time lies between 0 and 2x average-recovery-time
  if recovery-time > (average-recovery-time age) * 2 [ set recovery-time (average-recovery-time age) * 2 ]
  if recovery-time < 0 [ set recovery-time 4 ]

  ;; Similarly for isolation and hospital going tendencies
  if isolation-tendency > average-isolation-tendency * 2 [ set isolation-tendency average-isolation-tendency * 2 ]
  if isolation-tendency < 0 [ set isolation-tendency 0 ]
end

to-report gender-discount [gender]
  if gender = "F" [report 0.8]
  report 1
end


;; Different people are displayed in 5 different colors depending on health
;; green is a survivor of the infection
;; red is an infected person
;; white is neither infected nor cured

to assign-color ;; turtle procedure
  ifelse cured?
    [ set color green ]
      [ ifelse infected?
        [set color red ]
        [set color white]]
end

;;;
;;; GO PROCEDURES
;;;

to go
  if all? turtles [ not infected? ][
    print-final-summary
    stop
  ]
  ask turtles
    [ clear-count ]

  ask turtles
    [ if infected? and not hospitalized? and infection-length >= incubation-days
         [ infect ] ]

  ask turtles
    [ if not isolated? and not hospitalized? and infected? and symptomatic? and (random 100 < isolation-tendency)
        [ isolate ] ]

  ask turtles
    [ if not hospitalized? and infected? and severe-symptoms?
      [ hospitalize] ]

  ask turtles
    [ if infected?
      [
        set infection-length infection-length + 1
        if severe-symptoms? and infection-length = recovery-time [maybe-die]
        if symptomatic? and not severe-symptoms? and infection-length = recovery-time [maybe-worsen]
        if not symptomatic? and infection-length = symptom-time [maybe-show-symptoms]
        if symptomatic? and not isolated? [if random 100 < isolation-tendency [isolate]]
        maybe-recover
      ]
  ]

  ask turtles
    [ if (isolated? or hospitalized?) and cured?
        [ unisolate ] ]

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
;; If he doesn't the infection will finish its course and the person will be healed.
to maybe-show-symptoms
  if prob-symptoms > random 100 [
    ;show "DEBUG: I have the symptoms!"
    set symptomatic? true
    set infection-length 0
  ]
end

;; If the person worsens, after 7 days he will have a chance of dying/healing.
to maybe-worsen
  if probability-of-worsening age * gender-discount sex > random 100 [
    set severe-symptoms? true

    ;; if the person deteriorates it takes circa 7 days from now to recover or die
    set recovery-time round (infection-length + random-normal 7 2 )
    ;show "DEBUG: I'm worsening!"
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
      ;set susceptible? false     ;; We assume immunity is acquired...
      set nb-recovered (nb-recovered + 1)
      if hospitalized? [set in-hospital in-hospital - 1]
      if isolated? [unisolate]
    ]
  ]
end

to kill-agent
  ask my-links [die]
  set dead? true
  if count turtles with [dead?] = 1 [
    output-print (word "Epidemic day " ticks ": death number 1. Age: " age "; gender: " sex)
    output-print (word "Duration of agent's infection: " symptom-time " days incubation + " infection-length " days of illness")
    print-current-summary
    ifelse lockdown-at-first-death [lockdown][
      output-print " ================================ "
      output-print "NOT locking down"]
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

;; To hospitalize, remove all links. Recovery time increases, as the matter is serious.
to hospitalize ;; turtle procedure
  set hospitalized? true
  set in-hospital in-hospital + 1
  ask my-links [set removed? true]
  set isolated? true
  set pcolor black
  if show-layout [
    move-to patch (max-pxcor / 2) 0
    ask my-links [set removed? true]
    set pcolor white
  ]
end

to lockdown
  output-print " ================================ "
  output-print (word "Day " ticks ": Now locking down!")
  ask friendships [set removed? true]
  ask relations [set removed? true]
end


;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible friends and family.

to infect  ;; turtle procedure
  let spreader self
  let proportion 100
  let all-contacts turtles
  let random-passerby nobody

  if use-network? [
    set proportion 10
    set all-contacts friendship-neighbors
    set random-passerby one-of turtles
  ]

  if count all-contacts > 0 [
    ask n-of (1 + random round (count all-contacts / proportion)) all-contacts [
    ;ask n-of 1 nearby-uninfected [
      ifelse use-network?
      [if not infected? and not cured? and not [removed?] of link-with spreader [if random 100 < infection-chance [newinfection spreader]]]
      [if not infected? and not cured? and not isolated? and not [isolated?] of spreader and random 100 < infection-chance [newinfection spreader]]]
  ]

  if any? household-neighbors  [
    ask one-of household-neighbors [
      if not infected? and not cured? and not [removed?] of link-with spreader [if random 100 < infection-chance [newinfection spreader]]
    ]
  ]

;; Uncomment this if we want an infected agent to also try and infect someone at random
;  if random-passerby != nobody and not [isolated?] of spreader [
;    ask random-passerby [
;      if not infected? and not cured? [if random 100 < infection-chance [newinfection spreader]]
;    ]
;  ]
end

to newinfection [spreader]
  set infected? true
  set symptomatic? false
  set severe-symptoms? false
  set nb-infected (nb-infected + 1)
  set infected-by spreader
  ask spreader [set spreading-to lput myself spreading-to]
end

to calculate-r0
  let new-infected sum [ nb-infected ] of turtles
  let new-recovered sum [ nb-recovered ] of turtles
  set nb-infected-previous (count turtles with [ infected? ] + new-recovered - new-infected)  ;; Number of infected people at the previous tick
  let susceptible-t (N-people - (count turtles with [ infected? ]) - (count turtles with [ cured? ]))  ;; Number of susceptibles nowinfect
  let s0 count turtles with [ susceptible? ] ;; Initial number of susceptibles

  ifelse nb-infected-previous < 10
  [ set beta-n 0 ]
  [
    set beta-n (new-infected / nb-infected-previous)       ;; This is the average number of new secondary infections per infected this tick
  ]

  ifelse nb-infected-previous < 5
  [ set gamma 0 ]
  [
    set gamma (new-recovered / nb-infected-previous)     ;; This is the average number of new recoveries per infected this tick
  ]

  if ((N-people - susceptible-t) != 0 and (susceptible-t != 0))   ;; Prevent from dividing by 0
  [
    ;; This is derived from integrating dI / dS = (beta*SI - gamma*I) / (-beta*SI)
    ;; Assuming one infected individual introduced in the beginning, and hence counting I(0) as negligible,
    ;; we get the relation
    ;; N - gamma*ln(S(0)) / beta = S(t) - gamma*ln(S(t)) / beta, where N is the initial 'susceptible' population.
    ;; Since N >> 1
    ;; Using this, we have R_0 = beta*N / gamma = N*ln(S(0)/S(t)) / (K-S(t))
    set r0 (ln (s0 / susceptible-t) / (N-people - susceptible-t))
    set r0 r0 * s0 ]
end

;; make the initial network of initial-links-per-age-group edges per age group
to make-initial-links
  foreach (list [6 10][11 14][15 19][20 25][26 36][37 49][50 65][66 80][81 103]) [a-g ->
    repeat initial-links-per-age-group [
      ask one-of turtles with [age >= item 0 a-g and age <= item 1 a-g] [
        create-friendship-with one-of other turtles with [age >= item 0 a-g and age <= item 1 a-g] [
          set color green
          set mean-age mean [age] of both-ends
        ]
      ]
    ]
  ]
end

;; This code is the heart of the "preferential attachment" mechanism, and acts like
;; a lottery where each node gets a ticket for every connection it already has.
;; While the basic idea is the same as in the Lottery Example (in the Code Examples
;; section of the Models Library), things are made simpler here by the fact that we
;; can just use the links as if they were the "tickets": we first pick a random link,
;; and than we pick one of the two ends of that link.
to-report find-partner
  let partner nobody
  let connection one-of friendships with [abs ([age] of myself - mean-age) <= 12]   ; 80% of friendships within 12 years of age difference
  if random 100 < 20 [set connection one-of friendships]
  ifelse age >= 25 [
    if random 100 <= 15 [set connection one-of friendships]
  ][ifelse age >= 15
    [set connection one-of friendships with [mean-age - [age] of myself <= 8]]
    [if age > 12 [set connection one-of friendships with [mean-age - [age] of myself <= 5]]]
  ]
  ask connection [
    ifelse member? myself both-ends
    [set partner other-end]
    [set partner one-of both-ends]
  ]
  report partner
end

;; =================== SUMMARY ==================

to print-current-summary
  let infected count turtles with [infected?]
  let recovered count turtles with [cured?]
  let propinf precision (infected / N-people) 3
  let proprec precision (recovered / N-people) 3
  let proprec2 precision (recovered / (infected + count turtles with [cured?])) 3
  output-print (word "Currently infected: " infected " (" (propinf * 100) "% of population)" )
  output-print (word "Currently recovered: " recovered " (" (proprec * 100) "% of population - " (proprec2 * 100) "% of all infected)" )
  output-print (word "Current average R0: " precision r0 2)
end

to print-final-summary
  let totalinf count turtles with [ cured? ] + count turtles with [ infected? ]
  let totalinfpct precision ((totalinf / N-people) * 100) 3
  let deaths count turtles with [dead?]
  output-print " ================================ "
  output-print (word "End of epidemic: day " ticks)
  output-print (word "Total infected: " totalinfpct "% of population" )
  output-print (word "Total deaths: " deaths " - Mortality rate: " precision ((deaths / totalinf) * 100) 2 "%")
  output-print (word "R0: " precision r0 2)
end


;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count link-neighbors ]
  ]
  [
    ask turtles [ set size 1 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
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
8
720
91
753
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
95
719
178
752
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
80.0
5
1
NIL
HORIZONTAL

PLOT
10
350
405
541
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

PLOT
7
549
409
716
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
280
720
350
765
R0
r0
2
1
11

PLOT
11
170
405
345
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
8.0
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
182
721
275
755
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
120
1044
476
1071
====== \"Friendship\" network ======
20
0.0
1

MONITOR
355
720
423
765
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
34

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
9
775
415
1029
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
