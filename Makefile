PROJECTS = FilterDelays YUtils

all list clean: $(PROJECTS)
$(PROJECTS):
	$(MAKE) -C src/$@ $(MAKECMDGOALS)