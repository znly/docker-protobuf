LANGS := go gogo python swift c cpp cpplite js ruby java javalite javanano csharp objc php rust

ifneq ($(filter go gogo,$(LANGS)),)
ifndef GO_GEN_PKG
$(error trying to generate go/gogo and GO_GEN_PKG is not defined)
endif
endif

SED := sed
TR := tr
GREP := grep
FIND := find
AWK := awk
ECHO := echo
VENDOR_PATH := vendor
PROTOC := protoc
PWD := $(shell pwd)
PROTOC_FLAGS := -I$(PWD)

GEN_DIR := $(PWD)/gen
GOOGLE_WKT := any duration descriptor empty field_mask struct timestamp wrappers
GOGO_WKT_PKG := github.com/gogo/protobuf/types
GOOGLE_WKT_PROTO := $(GOOGLE_WKT:%=google/protobuf/%.proto)

GEN_DIRS := $(LANGS:%=$(GEN_DIR)/%)

PROTO_SRC_CMD := $(FIND) * -type f -name '*.proto' -not -path '$(GEN_DIR)/*' -not -path '$(VENDOR_PATH)/*'
PROTO_SRC := $(shell $(PROTO_SRC_CMD))
PROTO_PKG := $(shell $(PROTO_SRC_CMD) -exec dirname {} \; | sort | uniq)

protoc = protoc $(1) $(PROTOC_FLAGS)

, := ,
SPACE :=
SPACE +=


define newline


endef

# Parses out the proto files to extract communly used information
$(eval $(subst ;,$(newline),$(shell grep -E '^message \w+ \{' $(PROTO_SRC) | tr ':' ' '  | awk '{print "PROTO_MESSAGES_" $$1 " := $$(PROTO_MESSAGES_" $$1 ") " $$3}' | tr '\n' ';')))
$(eval $(subst ;,$(newline),$(shell grep -E '^option ' $(PROTO_SRC) | tr ':' ' ' | awk '{print "PROTO_OPTION_" $$1 "_" $$3 " := $$(PROTO_OPTION_" $$1 "_" $$3 ") " $$5}' | tr -d '";"' | tr '\n' ';')))
$(eval $(subst ;,$(newline),$(shell grep -E '^service \w+ \{' $(PROTO_SRC) | tr ':' ' '  | awk '{print "PROTO_SERVICES_" $$1 " := $$(PROTO_SERVICES_" $$1 ") " $$3}' | tr '\n' ';')))

proto_get_messages = $(strip $(PROTO_MESSAGES_$(1)))
proto_get_option = $(strip $(PROTO_OPTION_$(1)_$(2)))
proto_get_option_or_default = $(if $(call proto_get_option,$(1),$(2)),$(call proto_get_option,$(1),$(2)),$(3))
proto_get_services = $(strip $(PROTO_SERVICES_$(1)))
proto_has_services = $(if $(call proto_get_services,$(1)),$(1),)

letters_uc := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
letters_lc := a b c d e f g h i j k l m n o p q r s t u v w x y z

zip = $(join $(addsuffix :,$(1)),$(2))
unzip = $(subst :,$(SPACE),$(1))

str_camel_case = _$(1)
define make_str_camel_case
str_camel_case = $$(subst $(firstword $(1)),$(lastword $(1)),$(value str_camel_case))
endef
$(foreach p,$(call zip,$(addprefix _,$(letters_lc)),$(letters_uc)),$(eval $(call make_str_camel_case,$(call unzip,$(p)))))

_title = _$(subst $(SPACE),_,$(1))
define make_title
_title = $$(subst $(firstword $(1)),$(lastword $(1)),$(value _title))
endef
$(foreach p,$(call zip,$(addprefix _,$(letters_lc)),$(addprefix _,$(letters_uc))),$(eval $(call make_title,$(call unzip,$(p)))))
str_title = $(strip $(subst _,$(SPACE),$(_title)))
title = $(str_title)

str_split = $(subst $(1),$(SPACE),$(2))
str_join = $(subst $(SPACE),$(1),$(2))

underscore_to_camelcase = $(strip $(subst $(SPACE),,$(call title,$(call str_split,_,$(1)))))


.PHONY: all
all: build_langs

doc:
	$(PROTOC) $(PROTOC_FLAGS) --doc_out=$(GEN_DIR) --doc_opt=markdown,README.md $(PROTO_SRC)

build_langs: $(LANGS) doc

$(GEN_DIRS):
	@mkdir -p $(@)

.PHONY: clean
clean:
	rm -rf $(GEN_DIR)



# Utility functions
# ==============================================================================

# filename retuns the filename from a file minus its extension
filename = $(basename $(notdir $(1)))

patsubst_multi = $(foreach s,$(2),$(patsubst $(1),$(s),$(3)))

# Yes, this is a stupid work around.
, := ,


# Language specific functions
# ==============================================================================

go_get_package = $(call proto_get_option_or_default,$(1),go_package,$(lastword $(call str_split,/,$(dir $(1)))))

# java_get_outer_classname gets the outer class name as configured in the proto
# file.
java_get_outer_classname = $(call proto_get_option_or_default,$(1),java_outer_classname,$(call underscore_to_camelcase,$(call filename,$(1)))Proto)

objc_get_objc_class_prefix = $(call proto_get_option_or_default,$(1),objc_class_prefix,$(call str_join,_,$(call str_title,$(call str_split,/,$(dir $(1)))))_)

# target_* methods allow to create a target from a proto file. Some laguages
# don't have straightforward file creation rules, so this method makes up for
# it.
target_java = $(dir $(1))$(call java_get_outer_classname,$(1)).java $(patsubst %,$(dir $(1))%Grpc.java,$(call proto_get_services,$(1)))
target_javalite = $(target_java)
target_javanano = $(subst $(dir $(1)),$(dir $(1))nano/,$(target_java))
target_objc = $(addprefix $(dir $(1)),$(call patsubst_multi,%.proto,%.pbobjc.m %.pbobjc.h,$(call underscore_to_camelcase,$(notdir $(1)))) $(call patsubst_multi,%.proto,%.pbrpc.m %.pbrpc.h,$(call underscore_to_camelcase,$(notdir $(call proto_has_services,$(1))))))
target_csharp = $(call underscore_to_camelcase,$(patsubst %.proto,%.cs,$(notdir $(1))) $(patsubst %.proto,%Grpc.cs,$(notdir $(call proto_has_services,$(1)))))
target_go = $(1:%.proto=%.pb.go)
target_gogo = $(target_go)
target_python = $(1:%.proto=%_pb2.py) $(patsubst %.proto,%_pb2_grpc.py,$(call proto_has_services,$(1)))
target_swift = $(1:%.proto=%.pb.swift) $(call patsubst_multi,%.proto,%.grpc.client.pb.swift %.grpc.server.pb.swift,$(notdir $(call proto_has_services,$(1))))
target_cpp = $(call patsubst_multi,%.proto,%.pb.cc %.pb.h,$(1)) $(call patsubst_multi,%.proto,%.grpc.pb.cc %.grpc.pb.h,$(call proto_has_services,$(1)))
target_cpplite = $(target_cpp)
target_js = $(1:%.proto=%_pb.js) $(patsubst %.proto,%_grpc_pb.js,$(call proto_has_services,$(1)))
target_ruby = $(1:%.proto=%_pb.rb) $(patsubst %.proto,%_services_pb.rb,$(call proto_has_services,$(1)))
target_php = $(patsubst %,$(call str_join,/,$(call str_title,$(call str_split,/,$(dir $(1)))))/%.php,$(call proto_get_messages,$(1)) $(patsubst %,%Client,$(call proto_get_services,$(1))))
target_rust = $(1:%.proto=%.rs)
target_c = $(1:%.proto=%.pb-c.c) $(1:%.proto=%.pb-c.h)

go_make_import_path_subst = M$(3)=$(2)/$(1)/$(patsubst %/,%,$(dir $(3)))
go_make_protoc_import_path = $(call str_join,$(,),$(foreach protofile,$(PROTO_SRC),$(call go_make_import_path_subst,$(1),$(GO_GEN_PKG),$(protofile))))

GOGO_GOOGLE_WKT_REPLACE = $(call str_join,$(,),$(GOOGLE_WKT_PROTO:%=M%=$(GOGO_WKT_PKG)))
GO_PKG_REPLACE := $(call go_make_protoc_import_path,go)
GOGO_PKG_REPLACE := $(call go_make_protoc_import_path,gogo),$(GOGO_GOOGLE_WKT_REPLACE)

define make_lang
GEN_DIR_$(1) := $(GEN_DIR)/$(1)

FILES_$(1) := $(patsubst %,$$(GEN_DIR_$(1))/%,$(foreach protofile,$(PROTO_SRC),$(call target_$(1),$(protofile))))

$(1): $$(FILES_$(1))
endef
$(foreach lang,$(LANGS),$(eval $(call make_lang,$(lang))))

define generate_go
	@$$(PROTOC) \
		--go_out=$(GO_PKG_REPLACE),import_path=$$(call go_get_package,$$(PROTO_FILE)),plugins=grpc:$$(PROTO_OUT_DIR) \
		$$(<)
	@$(SED) -i 's:golang.org/x/net/context:context:g' $$(@)
endef

define generate_gogo
	@$$(PROTOC) \
		--gogofaster_out=$(GOGO_PKG_REPLACE),import_path=$$(call go_get_package,$$(PROTO_FILE)),plugins=grpc:$$(PROTO_OUT_DIR) \
		$$(<)
	@$(SED) -i 's:golang.org/x/net/context:context:g' $$(@)
endef

define generate_python
	@$$(PROTOC) \
		--python_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_python_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(<)
endef

define generate_swift_pre
endef

define generate_swift
	@mkdir -p $$(TMP_DIR)/.grpc/
	@$$(PROTOC) \
		--swift_out=Visibility=Public,FileNaming=FullPath:$$(PROTO_OUT_DIR) \
		--swiftgrpc_out=$$(TMP_DIR)/.grpc/ \
		$$(PROTO_FILE)
	@-mv -f $$(TMP_DIR)/.grpc/*.client.pb.swift \
		$$(subst .pb.swift,.grpc.client.pb.swift,$$(@)) 2> /dev/null || true
	@-mv -f $$(TMP_DIR)/.grpc/*.server.pb.swift \
		$$(subst .pb.swift,.grpc.server.pb.swift,$$(@)) 2> /dev/null || true
endef

define generate_objc_pre
	@echo -e '\n\noption objc_class_prefix = "$$(call objc_get_objc_class_prefix,$$(PROTO_FILE))";' >> $$(PROTO_TMP_FILE)
endef

define generate_objc
	@$$(PROTOC) \
		--objc_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_objective_c_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_cpp
	@$$(PROTOC) \
		--cpp_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_cpp_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_cpplite_pre
	@echo -e '\n\noption optimize_for = LITE_RUNTIME;' >> $$(PROTO_TMP_FILE)
endef

define generate_cpplite
	@$$(PROTOC) \
		--cpp_out=lite:$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_cpp_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef
cpplite:


define generate_js
	@$$(PROTOC) \
		--js_out=import_style=commonjs,binary:$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_node_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_ruby
	@$$(PROTOC) \
		--ruby_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_ruby_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_csharp
	@$$(PROTOC) \
		--csharp_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_csharp_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_java_tmp
	@echo -e '\n\noption java_outer_classname = "$$(call java_get_outer_classname,$$(PROTO_FILE))";' >> $$(PROTO_TMP_FILE)
endef

define generate_java

	@$$(PROTOC) \
		--java_out=$$(PROTO_OUT_DIR) \
		--grpc-java_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_javalite_pre
	@echo -e '\n\noption java_outer_classname = "$$(call java_get_outer_classname,$$(PROTO_FILE))";' >> $$(PROTO_TMP_FILE)
	@echo -e '\n\noption optimize_for = LITE_RUNTIME;' >> $$(PROTO_TMP_FILE)
endef

define generate_javalite
	@$$(PROTOC) \
		--java_out=$$(PROTO_OUT_DIR) \
		--grpc-java_out=lite:$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_javanano
	@$$(PROTOC) \
		'--javanano_out=ignore_services=true,store_unknown_fields=true,java_outer_classname=$$(PROTO_FILE)|$$(call java_get_outer_classname,$$(PROTO_FILE)):$$(PROTO_OUT_DIR)' \
		--grpc-java_out=nano:$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define generate_php
	@$$(PROTOC) \
		--php_out=$$(PROTO_OUT_DIR) \
		--plugin=protoc-gen-grpc=/usr/bin/grpc_php_plugin \
		--grpc_out=$$(PROTO_OUT_DIR) \
		$$(<)
endef

define generate_rust
	@mkdir -p $$(dir $$(@))
	@$$(PROTOC) \
		--rust_out=$$(dir $$(@)) \
		$$(PROTO_FILE)
endef

define generate_c
	@$$(PROTOC) \
		--c_out=$$(PROTO_OUT_DIR) \
		$$(PROTO_FILE)
endef

define make_file_target
TARGETS_$(1)_$(2) := $$(patsubst %,$(GEN_DIR_$(1))/%,$(3))
PRIMARY_TARGET_$(1)_$(2) := $$(firstword $$(TARGETS_$(1)_$(2)))
SECONDARY_TARGETS_$(1)_$(2) := $$(wordlist 2,$$(words $$(TARGETS_$(1)_$(2))),$$(TARGETS_$(1)_$(2)))

$$(PRIMARY_TARGET_$(1)_$(2)): PROTO_FILE := $(2)
ifdef generate_$(1)_pre
$$(PRIMARY_TARGET_$(1)_$(2)): PROTO_TMP_DIR := $(shell mktemp -d)
$$(PRIMARY_TARGET_$(1)_$(2)): PROTO_TMP_FILE := $$(PROTO_TMP_DIR)/$$(PROTO_FILE)
$$(PRIMARY_TARGET_$(1)_$(2)): PROTOC := $(PROTOC) -I$$(PROTO_TMP_DIR) $(PROTOC_FLAGS)
else
$$(PRIMARY_TARGET_$(1)_$(2)): PROTOC := $(PROTOC) $(PROTOC_FLAGS)
endif
$$(PRIMARY_TARGET_$(1)_$(2)): PROTO_OUT_DIR := $(GEN_DIR_$(1))
$$(PRIMARY_TARGET_$(1)_$(2)): $(2) $(GEN_DIR_$(1))
	@echo protoc/$(1) $(2) - $$(TARGETS_$(1)_$(2))
ifdef generate_$(1)_pre
	@cp -p --parents $$(PROTO_FILE) $$(PROTO_TMP_DIR)
	$(call generate_$(1)_pre)
endif
	$(call generate_$(1))

ifneq ($$(SECONDARY_TARGETS_$(1)_$(2)),)
$$(SECONDARY_TARGETS_$(1)_$(2)): $$(PRIMARY_TARGET_$(1)_$(2))
endif
endef
$(foreach lang,$(LANGS), \
	$(foreach protofile,$(PROTO_SRC),$(eval $(call make_file_target,$(lang),$(protofile),$(call target_$(lang),$(protofile))))))
