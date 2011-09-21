ROOT_SRC_DIR       = ../../
IMPORT_DEST        = $(ROOT_SRC_DIR)../include
PACKAGE_PATH       = dbi/pg/
PACKAGE_FULL_PATH  = $(IMPORT_DEST)/$(PACKAGE_PATH)
DFLAGS_REQ         = -I$(ROOT_SRC_DIR)
OBJ_PATH           = $(ROOT_SRC_DIR)../build
BUILD_PATH         = $(OBJ_PATH)/dbi/pg/
SRC                = $(wildcard *.d)
OBJ                = $(SRC:.d=.o)
build: pg-build
install: pg-install
clean: pg-clean
mrproper: pg-mrproper
.PHONY: clean mrproper pg-mrproper pg-clean
%.o: %.d
	$(DC) $(DFLAGS) $(DFLAGS_REQ) $< $(HD)$(PACKAGE_FULL_PATH) $(OF)$(BUILD_PATH)$@
pg-build: $(OBJ)
pg-install:
	@($(MKDIR) $(INCLUDEDIR)/$(PACKAGE_PATH))
	@($(CPR)   $(PACKAGE_FULL_PATH)/*.di $(INCLUDEDIR)/$(PACKAGE_PATH))
pg-clean:
	(cd $(OBJ_PATH); $(RMR) $(OBJ))
pg-mrproper:
	$(RMR) $(ROOT_SRC_DIR)$(PACKAGE_FULL_PATH)
pg-phony: .PHONY
