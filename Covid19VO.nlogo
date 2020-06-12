__includes ["DiseaseConfig.nls" "output.nls" "SocialNetwork.nls" "layout.nls" "scotland.nls" "work_distribution.nls"  ]


extensions [csv table]

undirected-link-breed [households household]
undirected-link-breed [relations relation]      ;; Relatives who don't live in the same household
undirected-link-breed [friendships friendship]
undirected-link-breed [tracings tracing]        ;; The contact tracing app
undirected-link-breed [wps wp]        ;; workplaces

globals
[
  rnd                  ;; Random seed

  b
  c
  fq
  use-existing-nw?
  show-layout

  ;; Behaviour
  average-isolation-tendency
  compliance-adjustment
  high-prob-isolating
  low-prob-isolating

  ;; Counters
  N-people
  tests-remaining
  tests-per-day
  tests-performed
  hospital-beds        ;; Number of places in the hospital (currently unused)
  counters             ;; Table containing information on source of infection e.g household, friends...
  populations          ;;
  cumulatives          ;; table of cumulative disease states
  infections           ;; table containing the average number of infections of people recovered or dead in the past week
  placecnt             ;;table of size of neigh and prop of young
  cum-infected
  work                 ;;table of agents by work-id
  ;; Reproduction rate
  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  s0                   ;; Initial number of susceptibles
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population
  rtime
  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-infected-previous
  nb-recovered         ;; Number of recovered people at the end of the tick

  ;; Interventions
  lockdown?            ;; If true we are in a state of lockdown
  contact-tracing      ;; If true a contact tracing app exists
  app-initalize?       ;; If the app was distributed to agents

  howmanyrnd           ;; Number of random people we meet
  howmanyelder         ;; Number of random people (> 67 y.o.) we meet

  ;; agent-sets
  seniors
  schoolkids
  adults
  working-age-agents
  workers              ;;people working in "offices"
  crowd-workers        ;; people working with crowd
  school               ;; Table of classes and pupils
  place                ;; Table of neighbourhoods and their residents             ;;
  work-place           ;list of work place size
  double-t
]

turtles-own
[
  sex
  age
  age-discount
  gender-discount
  status               ;; Marital status 0 = single 1 = married 2 = divorced 3 = widowed

  infected?            ;; If true, the person is infected.
  symptomatic?         ;; If true, the person is showing symptoms of infection
  severe-symptoms?     ;; If true, the person is showing severe symptoms
  cured?               ;; If true, the person has lived through an infection. They cannot be re-infected.

  isolated?            ;; If true, the person is isolated at home, unable to infect friends and passer-bys.
  days-isolated        ;; Number of days the agent has spent in self-isolation
  hospitalized?        ;; If true, the person is hospitalized.

  infected-by          ;; Agent who infected me
  spreading-to         ;; Number of agents infected by me

  chance-of-infecting  ;; Probability that the person (when infective) will infect someone he comes close with

  my-state             ;;describe the disease state of the agent: "incubation" "asymptomatic" "symptomatic" "severe" "in-hospital" "recovered" "dead"
  state-counter        ;;how long in this disease state
  t-incubation         ;;length of incubatiom
  t-asymptomatic       ;;length of asymtomatic
  t-symptomatic         ;;length of symptomatic
  t-severe             ;;duration untill severe is addmited to hospital
  t-hospital           ;;duration in hospital untill death or recovery
  t-infectious         ;; time in which agent become infectiuos
  t-stopinfecting      ;;time when agent stop infecting

  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine when symptomatic.
  testing-urgency      ;; When the person will seek to get tested after the onset of symptoms
  probability-of-dying
  probability-of-worsening

  susceptible?         ;; Tracks whether the person was initially susceptible

  ;; Agentsets
  friends
  relatives
  hh                   ;; household
  wide-colleagues
  close-colleagues
  myclass              ;; name of the pupil's class
  my-work              ;;identifier of work site, where  0- is not working
  my-work-sub          ;;identifier of sub work group
  out-grp              ;; instrumental variable to produce workgroups quickly

  office-worker?
  crowd-worker?        ;; if the worker works with crowd
  has-app?             ;; If true the agent carries the contact-tracing app
  tested-today?
  aware?

  neigh
  hhtype
]

friendships-own [mean-age]
households-own [ltype]  ; ltype 0 is a spouse; ltype 1 is offspring/sibling
wps-own [wp-id wtype]

tracings-own [day]

;; ===========================================================================
;;;
;;; SETUP
;;;
;; ==========================================================================

to setup
  set rnd ifelse-value use-seed? [-1114321144][new-seed]
  random-seed rnd
  ;show rnd ;if behaviorspace-run-number = 0 [output-print (word  "Random seed: " rnd)]

  ; set infection-chance 7.5 + random-float 1

  clear-all

  set show-layout false
  set use-existing-nw? true

  if impossible-run [
    reset-ticks
    stop
  ]

  set-default-shape turtles "circle"

  ifelse social-distancing? [
    set b 0.7
    set fq 2
    set c 0.7
  ][
    set b 1
    set fq 0
    set c 1
  ]

  set app-initalize? false

  ifelse use-existing-nw? [read-agents-sco][create-agents-sco]

  set N-people count turtles
  set-initial-variables

  ifelse use-existing-nw?
  [import-network]
  [
    create-hh-sco
    ask seniors [create-relations]
    create-friendships2
    remove-excess
  ]

  if schools-open? [foreach table:keys place [ngh -> create-schools-sco ngh]]

  ask turtles [
    reset-variables
    assign-disease-par
  ]

  if show-layout [
    resize-nodes
    repeat 50 [layout]
  ]

  reset-ticks

  infect-initial-agents


  ifelse use-existing-nw?
  [read-workplaces]
  [create-workplaces]

  set s0 table:get populations "susceptible"
  if behaviorspace-run-number = 0 [

    output-print (word "Infected agents: " [who] of turtles with [infected?])
    plot-friends
    plot-age
    ;plot-worksites
    set infections table:make
  ]
end

to set-initial-variables
  set average-isolation-tendency 70
  set compliance-adjustment ifelse-value app-compliance = "High" [0.9][0.5]
  ;;initially we start the expirement with no app-----------------------
  ;;ifelse pct-with-tracing-app > 0 [set contact-tracing true][]
  set contact-tracing false
  set high-prob-isolating ["symptomatic-individual" "household-of-symptomatic" "household-of-positive" "relation-of-symptomatic" "relation-of-positive" ]
  set low-prob-isolating ["app-contact-of-symptomatic" "app-contact-of-positive"]

  set counters table:from-list (list ["household" 0]["relations" 0]["friends" 0]["school" 0]["random" 0]["work" 0])
  set populations table:from-list (list ["susceptible" 0]["infected" 0]["recovered" 0]["isolated" 0]["dead" 0]["in-hospital" 0]["incubation" 0]["symptomatic" 0]["asymptomatic" 0]["severe" 0])
  set cumulatives table:from-list (list ["incubation" 0] ["asymptomatic" 0] ["symptomatic" 0] ["severe" 0 ] ["in-hospital" 0]["recovered" 0 ]["dead" 0])
  table:put populations "susceptible" N-people

  ;; initally there will be no tests------------------------------
  ;;set tests-per-day round ((tests-per-100-people / 100) * N-People / 7)
  set tests-per-day 0
  set tests-remaining tests-per-day
  set tests-performed 0

  ;; initially we don't distribute an app
  ;;let adults turtles with [age > 14]
  ;;ask n-of (round count adults * (pct-with-tracing-app / 100)) adults [set has-app? true]

  set lockdown? false
end

;; In this variant we test the situation of several countries with 5% cured and 0.5% infected
to infect-initial-agents

  ask n-of (round (N-people / 100) * initially-infected) turtles [
    change-state "incubation"
    table:put populations "infected" (table:get populations "infected" + 1)
    set infected? true
    set susceptible? false
  ]

  ask n-of (round (N-people / 100) * initially-cured) turtles with [infected? = false] [
    change-state "recovered"
    set cured? true
    set susceptible? false
  ]
end

to initial-app
  set contact-tracing ifelse-value pct-with-tracing-app > 0 [true][false]
  set tests-per-day round ((tests-per-100-people / 100) * N-People / 7)
  ask n-of (round count adults * (pct-with-tracing-app / 100)) adults [set has-app? true]
end

to reset-variables
  set state-counter 0
  set my-state "susceptible"
  set has-app? false
  set cured? false
  set isolated? false
  set hospitalized? false
  set infected? false
  set susceptible? true
  set symptomatic? false
  set severe-symptoms? false
  ; set dead? false
  set aware? false
  set spreading-to 0
  set infected-by nobody
  set office-worker? false
  set crowd-worker? false
  ifelse age <= 15 [set age-discount 0.5][set age-discount 1]
  ifelse sex = "F" [set gender-discount 0.8] [set gender-discount 1]
end

to read-agents
  let row 0
  foreach csv:from-file "lizzanello.csv" [ag ->
    let i 1
    if row > 0 [
      while [i < length ag][
        crt item i ag [
          set myclass 0
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
  set seniors turtles with [age >= 67]
  set schoolkids turtles with [age > 5 and age < 18]
  set working-age-agents turtles with [age > 22 and age < 67]
  set adults  turtles with [age > 14]
end
;=====================================================================================

to go
  if ticks = 0 and impossible-run [stop]

  if table:get populations "infected" = 0 [
    print-final-summary
    stop
  ]

  clear-count     ; this is to compute R0 the epiDEM's way
  ;;to initial the app onece 5% of the population are cured

  if app-initalize? = false [
    if table:get populations "recovered" / N-people > 0.05 [
      initial-app
      set app-initalize? true
    ]
  ]

  ; New tests are available every day
  set tests-remaining tests-remaining + tests-per-day
  ask turtles [set tested-today? false]

  ; The contact tracing app removes contacts older than 10 days
  if contact-tracing [ask tracings with [day < (ticks - 10)][die]]

  ask turtles with [isolated?] [
    set days-isolated days-isolated + 1
    if ((symptomatic? = false) and (days-isolated = 10)) [unisolate]
  ]

  ask turtles with [infected? and (not hospitalized?)] [   ;; we could exclude those still in the incubation phase here. We don't, so that we produce a few false positives in the app

    ; Infected agents (except those in hospital) infect others
    infect
    if ( member? my-state ["symptomatic" "severe"]) and (should-test?) and (state-counter = testing-urgency) [
      ifelse tests-remaining > 0
        [get-tested]
        [if not isolated? [maybe-isolate "symptomatic-individual"]]
    ]
  ]

  ;;crow workers work 5 days and may infect the crowd or be infected by the crowd
  ask crowd-workers with [(not isolated?) or (not cured?)][if 5 / 7 > random-float 1 [meet-people]]

  ;;after the infection between contactas took place during the day, at the "end of the day" agents change states
  ask turtles with [infected?][progression-disease]

  ifelse behaviorspace-run-number != 0
  [ save-individual ]
  [
    table:remove infections (ticks - 8)
    table:put infections ticks mean table:get-or-default infections ticks (list 0)
    if ticks = 7
      [set double-t 7
      set cum-infected table:get cumulatives "asymptomatic" + table:get cumulatives "symptomatic" + table:get cumulatives "severe"
     ]
    if (ticks > 7)  and (inc-rate >= 2) [
      print-double-time
      set double-t ticks
      set cum-infected table:get cumulatives "asymptomatic" + table:get cumulatives "symptomatic" + table:get cumulatives "severe"
    ]

    if show-layout [ask turtles [assign-color]]
    calculate-r0
    current-rt
  ]
  tick
end

to clear-count
  set nb-infected 0
  set nb-recovered 0
end

to change-state [new-state]
  table:put populations my-state (table:get populations my-state - 1)
  set my-state new-state
  table:put populations my-state (table:get populations my-state + 1)
  table:put cumulatives my-state (table:get cumulatives my-state + 1)
end


;; =========================================================================
;;                    PROGRESSION OF THE INFECTION
;; =========================================================================

;; After the incubation period the person may become asymptomatic or mild symptomatic or severe symptomatic. Severe are hospitlized within few days
to progression-disease

  set state-counter state-counter + 1

  ifelse (my-state = "incubation") [
    if (state-counter = t-infectious) [set chance-of-infecting infection-chance ]
    if (state-counter = t-incubation) [determine-progress]
  ][
    ifelse (my-state = "asymptomatic") [
      if (state-counter = t-asymptomatic) [recover]
      if (t-incubation - t-infectious + state-counter > 3) [set chance-of-infecting chance-of-infecting * 0.9] ;; we assume asymptomatic infectiousness declines at 3rd day
      ][ifelse (my-state = "symptomatic") and (state-counter = t-symptomatic) [recover][
        ifelse (my-state = "severe") and (state-counter = t-severe) [hospitalize][      ;;severe cases are hospitlized within several days
          if (my-state = "in-hospital") and (state-counter = t-hospital) [ifelse probability-of-dying > random 100  [kill-agent] [recover]]  ;patient either dies in hospital or recover
        ]
      ]
    ]
  ]
  if (member? my-state ["symptomatic" "asymptomatic"]) and (state-counter = t-stopinfecting) [set chance-of-infecting 0]  ;;stop being infectious after 7-11 days
;; agents states: "incubation" "asymptomatic" "symptomatic" "severe" "in-hospital" "recovered" "dead"
end

to determine-progress
  ifelse prob-symptoms > random 100 [
    ;show "DEBUG: I have the symptoms!"
    ifelse probability-of-worsening > random 100 [
      change-state "severe"
      set severe-symptoms? true
      set symptomatic? true
      set state-counter 0
    ]
    [change-state "symptomatic"
      set symptomatic? true
      set state-counter 0
    ]
  ]
  [ change-state "asymptomatic"
    set state-counter 0
  ]
end

to recover
  set state-counter 0
  change-state "recovered"
  table:put populations "infected" (table:get populations "infected" - 1)
  set infected? false
  set symptomatic? false
  set cured? true

  if behaviorspace-run-number = 0 [
    ifelse table:has-key? infections ticks
    [table:put infections ticks (lput spreading-to table:get infections ticks)]
    [table:put infections ticks (list spreading-to)]
  ]

  if hospitalized? [
    set hospitalized? false
    set isolated? false
  ]

  if isolated? [unisolate]
  set nb-recovered (nb-recovered + 1)
end

to kill-agent
  table:put populations my-state (table:get populations my-state - 1)
  table:put populations "infected" (table:get populations "infected" - 1)
  table:put populations "dead" (table:get populations "dead" + 1)
  table:put cumulatives "dead" (table:get cumulatives "dead" + 1)
  if hospitalized? [set isolated? false]
  if isolated? [table:put populations "isolated" (table:get populations "isolated" - 1)]

  if behaviorspace-run-number = 0 [
    ifelse table:has-key? infections ticks
    [table:put infections ticks lput spreading-to table:get infections ticks ]
    [table:put infections ticks (list spreading-to)]
  ]

  die

  if table:get populations "dead" = 1 [
    if lockdown-at-first-death [lockdown]
    if behaviorspace-run-number = 0 [
      output-print (word "Epidemic day " ticks ": death number 1. Age: " age "; gender: " sex)
      output-print (word "Duration of agent's infection: " t-incubation " days incubation + " (t-severe + t-hospital)  " days of illness")
      print-current-summary
    ]
  ]
end

;; ===============================================================================

to-report should-test?
  if not tested-today? and not aware? [report true]
  report false
end

to-report should-isolate?
  if not isolated? and not aware? and not tested-today? [report true]
  report false
end

to-report can-be-infected?
  if (not infected?) and (not aware?) [report true]
  report false
end

to maybe-isolate [origin]
  let tendency isolation-tendency
  if member? origin low-prob-isolating and not symptomatic? [set tendency tendency * compliance-adjustment]
  if random 100 < tendency [
    isolate
    ;; When someone in a household is isolating with symptoms, everybody else also should. Fixed probability here.
    if origin = "symptomatic-individual" [
      ask hh with [should-isolate?][maybe-isolate "household-of-symptomatic"]
      if any? relatives [ask relatives with [should-isolate?] [maybe-isolate "relation-of-symptomatic"]]
      if has-app? [ask tracing-neighbors with [should-isolate?] [maybe-isolate "app-contact-of-symptomatic"]]
    ]
  ]
end

;; When the agent is isolating all friendhips and relations are frozen. If she goes to school, she stops.
;; Crucially household links stay in place, as it is assumed that one isolates at home
;; Other household members may also have to isolate.
to isolate
  set isolated? true
  table:put populations "isolated" (table:get populations "isolated" + 1)
end

to unisolate  ;; turtle procedure
  set isolated? false
  table:put populations "isolated" (table:get populations "isolated" - 1)
  set days-isolated 0
end

to hospitalize ;; turtle procedure
  set state-counter 0
  change-state "in-hospital"
  set hospitalized? true
  set aware? true

  ;; We assume that hospitals always have tests. If I end up in hospital, the app will tell people.
  ask tracing-neighbors with [should-test?] [
    ifelse tests-remaining > 0
    [get-tested]
    [if not isolated? [maybe-isolate "app-contact-of-positive"]]
  ]
  ifelse not isolated? [set isolated? true]                 ;; The agent is isolated, so people won't encounter him around, but we don't count him
  [table:put populations "isolated" table:get populations "isolated" - 1]

  set pcolor black

  if show-layout [
    move-to patch (max-pxcor / 2) 0
    set pcolor white
  ]
end

;=====================================================================================

to meet-people
  let here table:get placecnt neigh
  let nmMeet (0.015 * item 0 here) * c ;;gives 1% of the people in the neigh
  let propelderly  0.5 * (1 - item 1 here) ;;gives 50% of the proportion of the elderly in the neigh
  set howmanyelder round (nmMeet * propelderly)
  set howmanyrnd nmMeet - howmanyelder

  let spreader self
  let chance chance-of-infecting
  let victim self
  let locals other table:get place neigh
  let crowd (turtle-set

    up-to-n-of random-poisson (howmanyrnd ) locals with [ age < 67]
    up-to-n-of random-poisson (howmanyelder) locals with [age > 67])

  ifelse infected?  [
    ;; Here the worker is infecting others
    ask crowd [
      if (can-be-infected?) and (not isolated?) [
        if has-app? and [has-app?] of spreader [add-contact spreader]
        if (not cured?) and random 100 < ((chance * age-discount) * 0.1 * b) [newinfection spreader "random"]  ; If the worker infects someone, it counts as random
      ]
    ]
  ]
  [
    ask crowd with [(infected?) and (not isolated?)] [
      ;; here the worker is being infected by others
        set spreader self
        set chance chance-of-infecting
        ask victim [
          if can-be-infected? [
            if has-app? and [has-app?] of spreader [add-contact spreader]
            if (not cured?) and random 100 < ((chance * 0.1) * b) [newinfection spreader "work"] ; If the worker is infected by someone, it's work.
          ]
        ]

    ]
  ]
end

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible friends and family.
;; We allow people to meet others even before they are infective so that the app will record these
;; interactions and produce a few false positives

to infect  ;; turtle procedure
  ;; Number of people we meet at random every day: 1 per 1000 people. Elderly goes out 1/2 less than other
  let here table:get placecnt neigh

  let nmMeet (0.005 * item 0 here) * c ;;gives 0.5% of the people in the neigh
  let propelderly  0.5 * (1 - item 1 here) ;;gives 50% of the proportion of the elderly in the neigh
  set howmanyelder round(nmMeet * propelderly)
  set howmanyrnd nmMeet - howmanyelder
  let spreader self
  let chance chance-of-infecting

  ;; Every day an infected person risks infecting all other household members. Even if the agent is isolating or there's a lockdown.
  if count hh > 0  [
    let hh-infection-chance chance

    ;; if the person is isolating the people in the household will try to stay away...
    if isolated? [set hh-infection-chance hh-infection-chance * 0.7]
    ask hh with [(not cured?) and can-be-infected?] [
      if random 100 < (hh-infection-chance * age-discount) [newinfection spreader "household"]
    ]
  ]

  ;; When there's no lockdown, and we are not isolated, we go out and infect other people.
  if (not isolated?) and (not lockdown?) [

    ;; Infected agents will infect someone at random. The probability is 1/10 of the normal infection-chance
    ;; Here, again, if both parties have the app a link is created to keep track of the meeting
    let random-passersby nobody
    if (age <= 67 or 0.5 > random-float 1) [
      let locals table:get place neigh
      set random-passersby (turtle-set
        up-to-n-of random-poisson howmanyrnd other locals with [age < 65 ]
        up-to-n-of random-poisson howmanyelder other locals with [age > 65 ]
      )
    ]

    let proportion 10

    if ((5 - fq) / 7) > random-float 1 [   ; 5/7 times kids go to school and adults go to work

      ifelse age > 5 and age < 18 [
        if schools-open?  [
          set proportion 20      ;; Children who go to school will meet less friends
                                 ;; Schoolchildren meet their schoolmates every SCHOOLDAY, and can infect them.
          let classmates table:get school myclass
          set classmates classmates  with [isolated? = false]
          ask n-of ((count classmates / 2) * c) other classmates [
            if can-be-infected? [
              if has-app? and [has-app?] of spreader [add-contact spreader]
              if (not cured?) and random 100 < (chance * age-discount) [newinfection spreader "school"]
            ]
          ]
        ]
      ]
      [
        if office-worker? [
          let todaysvictims (turtle-set n-of (count close-colleagues * c) close-colleagues one-of wide-colleagues)
          ask todaysvictims [if can-be-infected? and (not isolated?) [
            if has-app? and [has-app?] of spreader [add-contact spreader]
            if (not cured?) and random 100 < (chance * b) [newinfection spreader "work"]
            ]
          ]
        ]
      ]
    ]

    if ((7 - fq) / 7) > random-float 1 [

      ;; First, we go for our friends
      if (age <= 67 or 0.5 > random-float 1) [    ;;; Old people only meet friends on even days (= go out half of the times younger people do).
                                                  ;;; Every day the agent meets a certain fraction of her friends.
                                                  ;;; If the agent has the contact tracing app, a link is created between she and the friends who also have the app.
                                                  ;;; If the agent is infective, with probability infection-chance, he infects the susceptible friends who he's is meeting.
        if count friends > 0 [
          let howmany min (list (1 + random round (count friends / proportion)) 50)
          ask n-of howmany friends [
            if not isolated? and can-be-infected? [
              if has-app? and [has-app?] of spreader [add-contact spreader]
              if (not cured?) and random 100 < ((chance * age-discount) * b) [newinfection spreader "friends"]]
          ]
        ]
      ]
    ]

    ;; Every week we visit granpa twice and risk infecting him
    if count relatives > 0  and (2 / 7) > random-float 1 [
      ask one-of relatives [
        if can-be-infected? and (not isolated?) [
          if (not cured?) and random 100 < ((chance * age-discount) * b) [newinfection spreader "relations"]
        ]
      ]
    ]

    ;; Here we determine who are the unknown people we encounter. This is the 'random' group.
    ;; If we are isolated or there is a lockdown, this is assumed to be zero.
    ;; Elderly people are assumed to go out half as much as everyone else
    ;;currently an individual meets  a draw from poisson distribution with average howmanyrnd or howmanyelder
    if random-passersby != nobody [
      ask random-passersby [
        if (can-be-infected?) and (not isolated?)  [
          if has-app? and [has-app?] of spreader [add-contact spreader]
          if (not cured?) and random 100 < ((chance * age-discount) * 0.1) [newinfection spreader "random"]
        ]
      ]
    ]
  ]
end

to add-contact [infected-agent]
  create-tracing-with infected-agent [set day ticks]
end

to newinfection [spreader origin]
  set infected? true
  set state-counter 0
  change-state "incubation"
  table:put populations "infected" (table:get populations "infected" + 1)
  set symptomatic? false
  set severe-symptoms? false
  set aware? false
  set nb-infected (nb-infected + 1)
  set chance-of-infecting 0
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
  close-schools
end

to remove-lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Removing lockdown!")
  ]
  set lockdown? false
  reopen-schools
end

to close-schools
  set schools-open? false
end

to reopen-schools
  set schools-open? true
end

to get-tested
  if not tested-today? [  ;; I'm only doing this because there are some who for some reason test more times on the same day and I can't catch them...
    ;show (word "  day " ticks ": tested-today?: " tested-today? " - aware?: " aware? "  - now getting tested")
    set tests-remaining tests-remaining - 1
    set tests-performed tests-performed + 1
    ; if tests-remaining = 0 and behaviorspace-run-number = 0 [output-print (word "Day " ticks ": tests finished")]

    ;; If someone is found to be positive they:
    ;; 1. Isolate, 2. Their household decides whether to isolate, 3. The relations visited this week also decide whether to isolate
    ;; 4. If they use the app, the contacts are notified and have the option of getting tested or isolate.
    if infected? [
      if should-isolate? [isolate]
      set tested-today? true
      set aware? true
      ask hh with [should-test?]   ;;check this: here it should be all household members who are not cured should isolate
      [if not isolated? [maybe-isolate "household-of-positive"]] ;;shouldn't we do one probability for the whole family- currently each of them decides separtly

      if any? relatives [
        ask relatives [
          if should-isolate?
            [ifelse tests-remaining > 0
              [get-tested]
              [maybe-isolate "relation-of-positive"]]
        ]
      ]

      if has-app? [
        ask tracing-neighbors with [should-test?] [
          ifelse tests-remaining > 0
          [ get-tested ]
          [ if not isolated? [maybe-isolate "app-contact-of-positive"]]
        ]
      ]
    ]
  ]
end

;; =======================================================

to-report impossible-run
  if pct-with-tracing-app = 0 and app-compliance = "High" [report true]
  report false
end

;;===================== work distribution ==================================
@#$#@#$#@
GRAPHICS-WINDOW
410
775
833
1199
-1
-1
2.065
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
170
170
250
203
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
250
170
315
203
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

PLOT
0
525
406
717
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
"Infected" 1.0 0 -2674135 true "" "plot table:get populations \"infected\""
"Dead" 1.0 0 -16777216 true "" "plot table:get populations \"dead\""
"Hospitalized" 1.0 0 -955883 true "" "plot table:get populations \"in-hospital\""
"Self-Isolating" 1.0 0 -13791810 true "" "plot table:get populations \"isolated\""

PLOT
0
720
409
888
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
5
30
150
63
infection-chance
infection-chance
0
50
8.0
0.1
1
%
HORIZONTAL

MONITOR
5
160
75
205
R0
r0
2
1
11

PLOT
5
345
405
520
Prevelance of Susceptible/Infected/Recovered
days
% total pop.
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"% Infected" 1.0 0 -2674135 true "" "plot (table:get populations \"infected\" / N-people) * 100"
"% Recovered" 1.0 0 -9276814 true "" "plot (table:get populations \"recovered\" / N-people) * 100"
"% Susceptible" 1.0 0 -10899396 true "" "plot (table:get populations \"susceptible\" / N-people) * 100"

BUTTON
195
310
290
343
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

MONITOR
815
300
883
345
Deaths
table:get populations \"dead\"
0
1
11

SWITCH
5
310
190
343
lockdown-at-first-death
lockdown-at-first-death
1
1
-1000

OUTPUT
325
15
1085
270
16

SLIDER
170
30
315
63
initially-infected
initially-infected
0
5
0.5
0.1
1
%
HORIZONTAL

PLOT
0
890
340
1085
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
"default" 1.0 1 -16777216 true "" ""

SLIDER
5
240
179
273
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
5
275
180
308
tests-per-100-people
tests-per-100-people
0
20
1.5
0.01
1
NIL
HORIZONTAL

SWITCH
170
135
315
168
use-seed?
use-seed?
1
1
-1000

MONITOR
895
300
965
345
Available
tests-remaining
0
1
11

MONITOR
80
160
157
205
current R0
rtime
4
1
11

PLOT
410
345
695
540
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
"Work" 1.0 0 -13840069 true "" "plot table:get counters \"work\""

SWITCH
180
240
315
273
schools-open?
schools-open?
0
1
-1000

TEXTBOX
5
10
380
30
Disease Configuration (see also DiseaseConfig.nls)
12
0.0
1

TEXTBOX
225
115
315
133
Runtime config
12
0.0
1

TEXTBOX
15
215
180
241
==| MITIGATIONS |==
14
0.0
1

BUTTON
295
310
420
343
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
970
300
1040
345
Performed
tests-performed
1
1
11

TEXTBOX
900
285
1000
303
Tests ======
11
0.0
1

PLOT
410
545
765
760
Age distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 false "" ""

TEXTBOX
50
80
145
98
Behaviour config
12
0.0
1

CHOOSER
10
100
148
145
app-compliance
app-compliance
"High" "Low"
1

SLIDER
170
65
315
98
initially-cured
initially-cured
0
100
7.0
0.1
1
%
HORIZONTAL

BUTTON
425
310
515
343
NIL
close-schools
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
520
310
620
343
NIL
reopen-schools
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
835
775
1135
1005
Degree distribution (log-log)
log(degree)
log(# of nodes)
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

PLOT
835
1000
1135
1245
Degree distribution
degree
# of nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
695
345
1040
540
Type of infection
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
"Symptomatic (mild)" 1.0 0 -955883 true "" "plot table:get cumulatives \"symptomatic\""
"Asymptomatic" 1.0 0 -13840069 true "" "plot table:get cumulatives \"asymptomatic\""
"Severe" 1.0 0 -2674135 true "" "plot table:get cumulatives \"severe\""

PLOT
770
545
1040
760
work-sites
# of workers on site
# of work  sites
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -14070903 true "" ""

SWITCH
180
275
330
308
social-distancing?
social-distancing?
1
1
-1000

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
  <experiment name="phase2" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="6.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="1.5"/>
      <value value="3"/>
      <value value="25"/>
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
    <enumeratedValueSet variable="initially-infected">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="5.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;Low&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speedtest" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="5.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="6.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;Low&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="create-net" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
export-network</setup>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="5.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="6.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-links-per-age-group">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="incubation-days">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="baseline" repetitions="80" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;Low&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="socialDist" repetitions="20" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="1.5"/>
      <value value="3"/>
      <value value="6"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
      <value value="&quot;Low&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
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
