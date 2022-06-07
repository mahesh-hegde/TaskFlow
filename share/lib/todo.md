# To-do List UI
* UI Improvements
	- AnimatedListView for schedule editor

* Small scale refactor
    // move logic to model or atleast separate methods
	// cleanup onChanged callbacks

* Move Up & Move Down in Schedule editor

* Move up & move down in task lists

* Proper autoscroll in ListView

* Schedule repeats at time of day
	- Edit repeats dialog

	[x] S M T W T F S
	[Time]

	[+]

* add Notifications to EditTask Dialog

	Notifications

	[x|+ 5/10/30 Minutes Ago] [x|+ 1 Hour Earlier]
	[+ Custom Duration Before Deadline : Blue Chip]
	[+ Custom Time of Day : Orange Chip]

	On pressing OK synchronize changes in list to notification table

* Insert task for next schedule invocation

* Schedule tune out

* Journal UI

* Make listview draggable instead of MoveUp, MoveDown

## Journal

After finishing a component, it can be added to journal

Journal Entry format
	Date: TODAY
	Time: Optional

* Add Journal Tab & Journal entry view

* 'Add journal entry' dialogue

Journal search: By text, By date, by associated task list / component

## UI
* Implement themes

* Implement preferences

* Polish schedule UI

# Tests
* Model tests

* UI Tests

## Performance Optimizations
* State management
	- Introduce a homegrown state management component
	or use MobX

* Optimize size
* Optimize memory use

