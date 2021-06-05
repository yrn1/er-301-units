PROJECTS = FilterDelays

all list emu clean: $(PROJECTS)
$(PROJECTS):
	$(MAKE) -C src/$@ $(MAKECMDGOALS)