PROJECTS = FilterDelays

all list clean: $(PROJECTS)
$(PROJECTS):
	$(MAKE) -C src/$@ $(MAKECMDGOALS)