#!/usr/bin/env python3
"""
Enhanced STM32 Migration Script (v3)
Combines parsing, restructuring, and middleware isolation of the original migrator with 
the advanced LTO configurations, dynamic MCU architecture flag maps, and diagnostic targets.
"""

import os
import sys
import shutil
import argparse
import glob
import re

class CombinedSTM32Migrator:
    def __init__(self, target_dir):
        self.target_dir = os.path.abspath(target_dir)
        self.template_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.mcu_family = None
        self.mcu_name = None
        self.linker_script = None
        self.startup_script = None
        self.has_fatfs = False
        self.has_usb = False
        self.core_files = []
        self.brd_files = []
        self.app_files = []

        # MCU Architecture configurations
        self.mcu_architectures = {
            "STM32L4": {
                "arch_flags": "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32l4"
            },
            "STM32F4": {
                "arch_flags": "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32f4"
            },
            "STM32G4": {
                "arch_flags": "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32g4"
            },
            "STM32F1": {
                "arch_flags": "-mcpu=cortex-m3 -mthumb -mfloat-abi=soft",
                "linker_prefix": "stm32f1"
            },
            "STM32L0": {
                "arch_flags": "-mcpu=cortex-m0plus -mthumb -mfloat-abi=soft",
                "linker_prefix": "stm32l0"
            },
            "STM32U3": {
                "arch_flags": "-mcpu=cortex-m33 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32u3"
            },
            "STM32F7": {
                "arch_flags": "-mcpu=cortex-m7 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32f7"
            },
            "STM32H7": {
                "arch_flags": "-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard",
                "linker_prefix": "stm32h7"
            }
        }

    def run(self):
        print(f"Starting combined migration of {self.target_dir}")
        print(f"Using template from {self.template_dir}")
        
        self._analyze_project()
        self._isolate_vendor_code()
        self._reorganize_source()
        self._setup_infrastructure()
        self._generate_build_guide()
        
        print("\nEnhanced migration complete!")
        print(f"[OK] Dynamic MCU family configuration applied: {self.mcu_family or 'Unknown'}")
        print(f"[OK] LTO-compatible static library structures established")
        print(f"[OK] MinSizeRel and Release LTO whole-archive configurations set up")
        print(f"Read HOW_TO_BUILD.md for build instructions.")

    def _analyze_project(self):
        print("\n--- Phase A: Analyzing Project ---")
        ioc_files = glob.glob(os.path.join(self.target_dir, "*.ioc"))
        if not ioc_files:
            print("Warning: No .ioc file found. Will try to infer MCU from file names.")
        else:
            with open(ioc_files[0], 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if line.startswith("Mcu.Family="):
                        self.mcu_family = line.strip().split('=')[1]
                    elif line.startswith("Mcu.UserName="):
                        self.mcu_name = line.strip().split('=')[1]
            print(f"Detected MCU Family: {self.mcu_family}, Name: {self.mcu_name}")

        ld_files = glob.glob(os.path.join(self.target_dir, "**", "*_flash.ld"), recursive=True)
        if ld_files:
            self.linker_script = os.path.basename(ld_files[0])
            print(f"Detected Linker Script: {self.linker_script}")
            
            # Infer family from linker script if missing
            if not self.mcu_family:
                match = re.search(r'stm32([a-z0-9]{2})', self.linker_script, re.IGNORECASE)
                if match:
                    self.mcu_family = "STM32" + match.group(1).upper()
                    print(f"Inferred MCU Family from linker script: {self.mcu_family}")

        s_files = glob.glob(os.path.join(self.target_dir, "**", "startup_*.s"), recursive=True)
        if s_files:
            self.startup_script = os.path.basename(s_files[0])
            print(f"Detected Startup Script: {self.startup_script}")

        mw_dir = os.path.join(self.target_dir, "Middlewares")
        if os.path.exists(mw_dir):
            if os.path.exists(os.path.join(mw_dir, "Third_Party", "FatFs")):
                self.has_fatfs = True
                print("Detected FatFs middleware.")
            if glob.glob(os.path.join(mw_dir, "ST", "STM32_USB*_Library")):
                self.has_usb = True
                print("Detected USB Device middleware.")

        # Also support checking if root folders already exist (e.g. for re-running)
        if os.path.exists(os.path.join(self.target_dir, "FATFS")):
            self.has_fatfs = True
            print("Detected FATFS config directory.")
        if os.path.exists(os.path.join(self.target_dir, "USB_DEVICE")):
            self.has_usb = True
            print("Detected USB_DEVICE config directory.")

    def _isolate_vendor_code(self):
        print("\n--- Phase B: Isolating Vendor Code ---")
        lib_dir = os.path.join(self.target_dir, "lib")
        os.makedirs(lib_dir, exist_ok=True)

        cmsis_src = os.path.join(self.target_dir, "Drivers", "CMSIS")
        if os.path.exists(cmsis_src):
            cmsis_dest = os.path.join(lib_dir, "CMSIS")
            if os.path.exists(cmsis_dest):
                shutil.rmtree(cmsis_dest)
            shutil.move(cmsis_src, cmsis_dest)
            print("Moved CMSIS to lib/")

        if self.mcu_family:
            hal_dir_name = f"{self.mcu_family}xx_HAL_Driver"
            hal_src = os.path.join(self.target_dir, "Drivers", hal_dir_name)
            if os.path.exists(hal_src):
                hal_dest = os.path.join(lib_dir, hal_dir_name)
                if os.path.exists(hal_dest):
                    shutil.rmtree(hal_dest)
                shutil.move(hal_src, hal_dest)
                print(f"Moved {hal_dir_name} to lib/")

        if self.has_fatfs:
            fatfs_src = os.path.join(self.target_dir, "Middlewares", "Third_Party", "FatFs")
            if os.path.exists(fatfs_src):
                fatfs_dest = os.path.join(lib_dir, "FatFs")
                if os.path.exists(fatfs_dest):
                    shutil.rmtree(fatfs_dest)
                shutil.move(fatfs_src, fatfs_dest)
                print("Moved FatFs to lib/")
        
        if self.has_usb:
            usb_srcs = glob.glob(os.path.join(self.target_dir, "Middlewares", "ST", "STM32_USB*_Library"))
            for usb_src in usb_srcs:
                usb_dest = os.path.join(lib_dir, os.path.basename(usb_src))
                if os.path.exists(usb_dest):
                    shutil.rmtree(usb_dest)
                shutil.move(usb_src, usb_dest)
                print(f"Moved {os.path.basename(usb_src)} to lib/")

        self._generate_lib_cmake()

    def _generate_lib_cmake(self):
        cmake_content = "cmake_minimum_required(VERSION 3.22)\n\nproject(lib)\nenable_language(C CXX ASM)\n\n"
        cmake_content += "add_library(lib STATIC)\n\n"
        
        # Suppress all warnings for vendor code
        cmake_content += "target_compile_options(lib PRIVATE \"-w\")\n\n"
        
        # Add compile definitions required by the HAL driver
        mcu_define = f"{self.mcu_family}xx"
        if self.mcu_name:
            match = re.match(r'(STM32[A-Z0-9]{4})', self.mcu_name)
            if match:
                mcu_define = match.group(1) + "xx"
        cmake_content += "target_compile_definitions(lib PRIVATE\n"
        cmake_content += f"    {mcu_define}\n"
        cmake_content += "    USE_HAL_DRIVER\n"
        cmake_content += ")\n\n"
        
        includes = [
            f"CMSIS/Device/ST/{self.mcu_family}xx/Include",
            "CMSIS/Include",
            f"{self.mcu_family}xx_HAL_Driver/Inc",
            f"{self.mcu_family}xx_HAL_Driver/Inc/Legacy",
            # HAL driver needs stm32xxxx_hal_conf.h from the project's bsp/core
            "${CMAKE_SOURCE_DIR}/src/bsp/core",
            # Vendor/middleware files often need to include main.h
            "${CMAKE_SOURCE_DIR}/src"
        ]
        if self.has_fatfs:
            includes.append("FatFs/src")
            # Include root FATFS/Target to find ffconf.h
            includes.append("${CMAKE_SOURCE_DIR}/FATFS/Target")
        if self.has_usb:
            includes.extend([
                "STM32_USB_Device_Library/Core/Inc",
                "STM32_USB_Device_Library/Class/CDC/Inc",
                # Include root USB_DEVICE/Target to find usbd_conf.h
                "${CMAKE_SOURCE_DIR}/USB_DEVICE/Target"
            ])

        cmake_content += "target_include_directories(lib PUBLIC\n"
        for inc in includes:
            cmake_content += f"    {inc}\n"
        cmake_content += ")\n\n"

        sources = []
        hal_dir = os.path.join(self.target_dir, "lib", f"{self.mcu_family}xx_HAL_Driver", "Src")
        if os.path.exists(hal_dir):
            for file in os.listdir(hal_dir):
                if file.endswith(".c") and not file.endswith("_template.c"):
                    sources.append(f"{self.mcu_family}xx_HAL_Driver/Src/{file}")
        
        if self.has_fatfs:
            fatfs_dir = os.path.join(self.target_dir, "lib", "FatFs", "src")
            if os.path.exists(fatfs_dir):
                for file in ["diskio.c", "ff.c", "ff_gen_drv.c", "option/syscall.c", "option/ccsbcs.c"]:
                    if os.path.exists(os.path.join(fatfs_dir, file)):
                        sources.append(f"FatFs/src/{file}")

        if self.has_usb:
             usb_core = os.path.join(self.target_dir, "lib", "STM32_USB_Device_Library", "Core", "Src")
             if os.path.exists(usb_core):
                 for file in os.listdir(usb_core):
                     if file.endswith(".c"):
                          sources.append(f"STM32_USB_Device_Library/Core/Src/{file}")
             usb_class = os.path.join(self.target_dir, "lib", "STM32_USB_Device_Library", "Class", "CDC", "Src")
             if os.path.exists(usb_class):
                 for file in os.listdir(usb_class):
                     if file.endswith(".c"):
                          sources.append(f"STM32_USB_Device_Library/Class/CDC/Src/{file}")

        cmake_content += "target_sources(lib PRIVATE\n"
        for src in sources:
            cmake_content += f"    {src}\n"
        cmake_content += ")\n\n"

        cmake_content += "# Export include paths for clang-tidy as system includes\n"
        cmake_content += "set(LIB_CLANG_TIDY_SYSTEM_INCLUDES\n"
        for inc in includes:
            cmake_content += f"    {inc}\n"
        cmake_content += ")\n\n"
        cmake_content += "# Prepend the include list with the path of the current directory\n"
        cmake_content += "list(TRANSFORM LIB_CLANG_TIDY_SYSTEM_INCLUDES\n     PREPEND ${CMAKE_CURRENT_SOURCE_DIR}/\n)\n\n"
        cmake_content += "# Export the collected system includes to the clang-tidy system includes list\n"
        cmake_content += "set(CLANG_TIDY_SYSTEM_INCLUDES\n    ${CLANG_TIDY_SYSTEM_INCLUDES}\n    ${LIB_CLANG_TIDY_SYSTEM_INCLUDES}\n    PARENT_SCOPE\n)\n"

        with open(os.path.join(self.target_dir, "lib", "CMakeLists.txt"), "w") as f:
            f.write(cmake_content)
        print("Generated lib/CMakeLists.txt")

    def _move_file(self, src_path, dest_dir):
        if os.path.exists(src_path):
            os.makedirs(dest_dir, exist_ok=True)
            shutil.move(src_path, os.path.join(dest_dir, os.path.basename(src_path)))
            return True
        return False

    def _reorganize_source(self):
        print("\n--- Phase C: Reorganizing Source Code ---")
        
        orig_src = os.path.join(self.target_dir, "Src")
        orig_inc = os.path.join(self.target_dir, "Inc")
        core_src = os.path.join(self.target_dir, "Core", "Src")
        core_inc = os.path.join(self.target_dir, "Core", "Inc")

        actual_dirs = os.listdir(self.target_dir) if os.path.exists(self.target_dir) else []

        if not os.path.exists(core_src) and "Src" in actual_dirs:
            core_src = orig_src
            print("Using root Src/ as core source directory.")
        if not os.path.exists(core_inc) and "Inc" in actual_dirs:
            core_inc = orig_inc
            print("Using root Inc/ as core include directory.")

        final_src = os.path.join(self.target_dir, "src")
        dirs_to_create = ["bsp/startup", "bsp/core", "bsp/brd", "app", "utils"]
        for d in dirs_to_create:
            os.makedirs(os.path.join(final_src, d), exist_ok=True)

        # Move startup scripts
        s_files = glob.glob(os.path.join(self.target_dir, "**", "startup_*.s"), recursive=True)
        for s_file in s_files:
            if "lib" in s_file or "cmake" in s_file or "src" in s_file: continue
            self._move_file(s_file, os.path.join(final_src, "bsp/startup"))
            print(f"Moved {os.path.basename(s_file)} to src/bsp/startup/")

        # Move linker scripts
        ld_files = glob.glob(os.path.join(self.target_dir, "**", "*_flash.ld"), recursive=True)
        for ld_file in ld_files:
            if "lib" in ld_file or "cmake" in ld_file or "src" in ld_file: continue
            if os.path.dirname(ld_file) != self.target_dir:
                 shutil.move(ld_file, os.path.join(self.target_dir, os.path.basename(ld_file)))
                 print(f"Moved {os.path.basename(ld_file)} to project root")

        # Move main files
        self._move_file(os.path.join(core_src, "main.c"), final_src)
        self._move_file(os.path.join(core_inc, "main.h"), final_src)

        core_patterns = ["gpio", "dma", "usart", "spi", "sdio", "tim", "adc", "rcc", "cortex", "flash", "sysmem", "syscalls", "stm32*_it", "stm32*_hal_msp", "system_stm32*", "stm32*_hal_conf"]
        brd_patterns = ["fatfs", "bsp_driver", "sd_diskio", "usb_device", "usbd_conf", "usbd_desc", "usbd_cdc_if"]

        for d in [core_src, core_inc]:
            if not os.path.exists(d): continue
            for file in os.listdir(d):
                filepath = os.path.join(d, file)
                if os.path.isdir(filepath): continue
                
                moved = False
                for p in core_patterns:
                    if re.match(p.replace("*", ".*") + r"\.[ch]$", file, re.IGNORECASE):
                        self._move_file(filepath, os.path.join(final_src, "bsp/core"))
                        self.core_files.append(file)
                        moved = True
                        break
                
                if not moved:
                    for p in brd_patterns:
                        if re.match(p.replace("*", ".*") + r"\.[ch]$", file, re.IGNORECASE):
                            self._move_file(filepath, os.path.join(final_src, "bsp/brd"))
                            self.brd_files.append(file)
                            moved = True
                            break
                
                if not moved and (file.endswith(".c") or file.endswith(".h")):
                    self._move_file(filepath, os.path.join(final_src, "app"))
                    self.app_files.append(file)
        
        # Cleanup original directories
        for d in [orig_src, orig_inc, core_src, core_inc]:
            if os.path.exists(d) and not os.listdir(d):
                os.rmdir(d)

        # Patch main.c warnings
        main_c_path = os.path.join(final_src, "main.c")
        if os.path.exists(main_c_path):
            with open(main_c_path, "r", encoding="utf-8", errors="ignore") as f:
                m_content = f.read()
            
            old_body = 'void assert_failed(uint8_t *file, uint32_t line)\n{\n  /* USER CODE BEGIN 6 */\n  /* User can add his own implementation to report the file name and line number,\n     ex: printf("Wrong parameters value: file %s on line %d\\r\\n", file, line) */\n  /* USER CODE END 6 */\n}'
            new_body = 'void assert_failed(uint8_t *file, uint32_t line)\n{\n  /* USER CODE BEGIN 6 */\n  (void)file;\n  (void)line;\n  /* USER CODE END 6 */\n}'
            
            if old_body in m_content:
                m_content = m_content.replace(old_body, new_body)
                with open(main_c_path, "w", encoding="utf-8") as f:
                    f.write(m_content)
                print("Patched main.c assert_failed")
            else:
                m_content = re.sub(
                    r'void assert_failed\(uint8_t \*file, uint32_t line\)\s*{\s*/\* USER CODE BEGIN 6 \*/.*?/\* USER CODE END 6 \*/\s*}',
                    new_body,
                    m_content,
                    flags=re.DOTALL
                )
                with open(main_c_path, "w", encoding="utf-8") as f:
                    f.write(m_content)
                print("Patched main.c assert_failed (regex)")

        print(f"Moved {len(self.core_files)} files to src/bsp/core/")
        print(f"Moved {len(self.brd_files)} files to src/bsp/brd/")
        print(f"Moved {len(self.app_files)} files to src/app/")

    def _setup_infrastructure(self):
        print("\n--- Phase D: Setting up Infrastructure ---")
        
        # Copy configuration files
        for file in [".clang-format", ".clang-tidy", ".editorconfig", ".gitignore", "CMakePresets.json"]:
            src_file = os.path.join(self.template_dir, file)
            if os.path.exists(src_file):
                shutil.copy(src_file, self.target_dir)
                print(f"Copied {file}")

        # Copy directories
        for directory in ["cmake", "scripts", "lint", "docs", ".vscode"]:
            src_dir = os.path.join(self.template_dir, directory)
            dest_dir = os.path.join(self.target_dir, directory)
            if os.path.exists(src_dir):
                if os.path.exists(dest_dir):
                    shutil.rmtree(dest_dir)
                def ignore_migration_script(dir, files):
                    return ["migrate_project.py"] if directory == "scripts" else []
                shutil.copytree(src_dir, dest_dir, ignore=ignore_migration_script)
                print(f"Copied {directory}/")
                
                # Cleanup non-matching MCU cmake files
                if directory == "cmake":
                    mcu_dir = os.path.join(dest_dir, "microcontrollers")
                    if os.path.exists(mcu_dir):
                        target_mcu_file = f"{self.mcu_family.lower()}-gcc.cmake"
                        for f in os.listdir(mcu_dir):
                            if f.endswith("-gcc.cmake") and f != target_mcu_file and f != "common.cmake":
                                os.remove(os.path.join(mcu_dir, f))
                                print(f"Removed unused {f}")
                
                # Update launch.json device and settings.json target name
                if directory == ".vscode":
                    launch_json = os.path.join(dest_dir, "launch.json")
                    if os.path.exists(launch_json):
                        with open(launch_json, "r", encoding="utf-8") as f:
                            l_content = f.read()
                        l_content = l_content.replace("STM32L496xx", self.mcu_name if self.mcu_name else "STM32XXXXxx")
                        l_content = re.sub(r'"svdFile": ".*?"', '"svdFile": ""', l_content)
                        with open(launch_json, "w", encoding="utf-8") as f:
                            f.write(l_content)
                        print("Updated .vscode/launch.json")

                    settings_json = os.path.join(dest_dir, "settings.json")
                    if os.path.exists(settings_json):
                        with open(settings_json, "r", encoding="utf-8") as f:
                            s_content = f.read()
                        s_content = s_content.replace("stm32-project-template-v2", os.path.basename(self.target_dir))
                        if self.mcu_family:
                            s_content = s_content.replace("stm32l4xx", f"{self.mcu_family.lower()}xx")
                            s_content = s_content.replace("stm32l496xx", f"{self.mcu_family.lower()}xx")
                        with open(settings_json, "w", encoding="utf-8") as f:
                            f.write(s_content)
                        print("Updated .vscode/settings.json target name and header associations")

                # Update helper scripts target name
                if directory == "scripts":
                    for script_name in ["flash.ps1", "build.ps1"]:
                        script_path = os.path.join(dest_dir, script_name)
                        if os.path.exists(script_path):
                            with open(script_path, "r", encoding="utf-8", errors="ignore") as f:
                                s_content = f.read()
                            s_content = s_content.replace("stm32-project-template-v2", os.path.basename(self.target_dir))
                            with open(script_path, "w", encoding="utf-8") as f:
                                f.write(s_content)
                            print(f"Updated scripts/{script_name} target name")

        # Generate MCU specific compiler config dynamically
        self._generate_dynamic_mcu_cmake()

        # Update root CMakeLists.txt
        template_cmake = os.path.join(self.template_dir, "CMakeLists.txt")
        if os.path.exists(template_cmake):
            with open(template_cmake, "r", encoding="utf-8") as f:
                content = f.read()
            
            content = re.sub(r'project\(.*?\)', f'project({os.path.basename(self.target_dir)})', content)
            mcu_short = self.mcu_family.lower()
            content = re.sub(r'include\(cmake/microcontrollers/stm32.*?-gcc\.cmake\)', f'include(cmake/microcontrollers/{mcu_short}-gcc.cmake)', content)
            
            mcu_define = f"{self.mcu_family}xx"
            if self.mcu_name:
                match = re.match(r'(STM32[A-Z0-9]{4})', self.mcu_name)
                if match:
                    mcu_define = match.group(1) + "xx"
            
            content = re.sub(r'set\(DEFINES\s+.*?STM32L496xx', f'set(DEFINES\n    {mcu_define}', content, flags=re.DOTALL)

            # Restructure include directories
            includes_str = "set(INCLUDES\n    ${PROJECT_SOURCE_DIR}/src\n    ${PROJECT_SOURCE_DIR}/src/bsp/core\n    ${PROJECT_SOURCE_DIR}/src/bsp/brd\n    ${PROJECT_SOURCE_DIR}/src/app\n)"
            if self.has_fatfs:
                includes_str = includes_str.replace(")", "    ${PROJECT_SOURCE_DIR}/FATFS/App\n    ${PROJECT_SOURCE_DIR}/FATFS/Target\n)")
            if self.has_usb:
                includes_str = includes_str.replace(")", "    ${PROJECT_SOURCE_DIR}/USB_DEVICE/App\n    ${PROJECT_SOURCE_DIR}/USB_DEVICE/Target\n)")
            
            content = re.sub(r'set\(INCLUDES.*?^\)', includes_str, content, flags=re.MULTILINE|re.DOTALL)

            # Rebuild sources list
            src_files = ["${PROJECT_SOURCE_DIR}/src/main.c"]
            
            # Scan directories directly if they already contain files, or fall back to self.core_files
            core_dir = os.path.join(self.target_dir, "src", "bsp", "core")
            if os.path.exists(core_dir) and os.listdir(core_dir):
                for f in sorted(os.listdir(core_dir)):
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/bsp/core/{f}")
            else:
                for f in self.core_files:
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/bsp/core/{f}")
                    
            brd_dir = os.path.join(self.target_dir, "src", "bsp", "brd")
            if os.path.exists(brd_dir) and os.listdir(brd_dir):
                for f in sorted(os.listdir(brd_dir)):
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/bsp/brd/{f}")
            else:
                for f in self.brd_files:
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/bsp/brd/{f}")
                    
            app_dir = os.path.join(self.target_dir, "src", "app")
            if os.path.exists(app_dir) and os.listdir(app_dir):
                for f in sorted(os.listdir(app_dir)):
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/app/{f}")
            else:
                for f in self.app_files:
                    if f.endswith(".c"): src_files.append(f"${{PROJECT_SOURCE_DIR}}/src/app/{f}")
            
            if self.has_fatfs:
                fatfs_app_path = os.path.join(self.target_dir, "FATFS", "App")
                fatfs_target_path = os.path.join(self.target_dir, "FATFS", "Target")
                if os.path.exists(fatfs_app_path):
                    for file in os.listdir(fatfs_app_path):
                        if file.endswith(".c"):
                            src_files.append(f"${{PROJECT_SOURCE_DIR}}/FATFS/App/{file}")
                if os.path.exists(fatfs_target_path):
                    for file in os.listdir(fatfs_target_path):
                        if file.endswith(".c"):
                            src_files.append(f"${{PROJECT_SOURCE_DIR}}/FATFS/Target/{file}")
                            
            if self.has_usb:
                usb_app_path = os.path.join(self.target_dir, "USB_DEVICE", "App")
                usb_target_path = os.path.join(self.target_dir, "USB_DEVICE", "Target")
                if os.path.exists(usb_app_path):
                    for file in os.listdir(usb_app_path):
                        if file.endswith(".c"):
                            src_files.append(f"${{PROJECT_SOURCE_DIR}}/USB_DEVICE/App/{file}")
                if os.path.exists(usb_target_path):
                    for file in os.listdir(usb_target_path):
                        if file.endswith(".c"):
                            src_files.append(f"${{PROJECT_SOURCE_DIR}}/USB_DEVICE/Target/{file}")
            
            sources_str = "set(SOURCES_C\n"
            for src in src_files:
                sources_str += f"    {src}\n"
            sources_str += ")"
            content = re.sub(r'set\(SOURCES_C.*?^\)', sources_str, content, flags=re.MULTILINE|re.DOTALL)
            
            if self.startup_script:
                asm_str = f"set(SOURCES_ASM\n    ${{PROJECT_SOURCE_DIR}}/src/bsp/startup/{self.startup_script}\n)"
                content = re.sub(r'set\(SOURCES_ASM.*?^\)', asm_str, content, flags=re.MULTILINE|re.DOTALL)

            # Generate middleware source list for warning suppression
            middleware_src_files = []
            if self.has_fatfs:
                fatfs_app_path = os.path.join(self.target_dir, "FATFS", "App")
                fatfs_target_path = os.path.join(self.target_dir, "FATFS", "Target")
                if os.path.exists(fatfs_app_path):
                    for file in sorted(os.listdir(fatfs_app_path)):
                        if file.endswith(".c"):
                            middleware_src_files.append(f"${{PROJECT_SOURCE_DIR}}/FATFS/App/{file}")
                if os.path.exists(fatfs_target_path):
                    for file in sorted(os.listdir(fatfs_target_path)):
                        if file.endswith(".c"):
                            middleware_src_files.append(f"${{PROJECT_SOURCE_DIR}}/FATFS/Target/{file}")
            if self.has_usb:
                usb_app_path = os.path.join(self.target_dir, "USB_DEVICE", "App")
                usb_target_path = os.path.join(self.target_dir, "USB_DEVICE", "Target")
                if os.path.exists(usb_app_path):
                    for file in sorted(os.listdir(usb_app_path)):
                        if file.endswith(".c"):
                            middleware_src_files.append(f"${{PROJECT_SOURCE_DIR}}/USB_DEVICE/App/{file}")
                if os.path.exists(usb_target_path):
                    for file in sorted(os.listdir(usb_target_path)):
                        if file.endswith(".c"):
                            middleware_src_files.append(f"${{PROJECT_SOURCE_DIR}}/USB_DEVICE/Target/{file}")

            if middleware_src_files:
                middleware_str = "\n# Suppress warnings in auto-generated CubeMX middleware files\nset(MIDDLEWARE_SOURCES\n"
                for m_src in middleware_src_files:
                    middleware_str += f"    {m_src}\n"
                middleware_str += ")\nset_source_files_properties(${MIDDLEWARE_SOURCES} PROPERTIES COMPILE_OPTIONS \"-w\")\n"
                if "set_source_files_properties" not in content:
                    content += middleware_str

            # Append dynamic diagnostic targets at the bottom of the CMake file
            diagnostic_targets = """
# ==============================================================================
# Enhanced Diagnostic Targets (Dynamic LTO and Footprint Utilities)
# ==============================================================================
add_custom_target(lto-info
    COMMAND ${CMAKE_COMMAND} -E echo "=== Link-Time Optimization (LTO) Status ==="
    COMMAND ${CMAKE_COMMAND} -E echo "Build Type: ${CMAKE_BUILD_TYPE}"
    COMMAND ${CMAKE_COMMAND} -E echo "Compiler flags: ${CMAKE_C_FLAGS}"
    COMMENT "Showing dynamic compiler LTO configurations"
)

add_custom_target(size-analysis
    COMMAND ${CMAKE_SIZE} -t $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
    COMMAND ${CMAKE_COMMAND} -E echo "=== Binary size summary compiled successfully ==="
    COMMENT "Running footprint size compilation check"
)
"""
            if "size-analysis" not in content:
                content += diagnostic_targets
                
            with open(os.path.join(self.target_dir, "CMakeLists.txt"), "w", encoding="utf-8") as f:
                f.write(content)
            print("Configured dynamic root CMakeLists.txt")

    def _generate_dynamic_mcu_cmake(self):
        print("\n--- Generating Dynamic MCU Compilation File ---")
        mcu_short = self.mcu_family.upper()
        
        # Identify hardware flag mapping
        arch_config = None
        for family, cfg in self.mcu_architectures.items():
            if family in mcu_short:
                arch_config = cfg
                break
        
        if not arch_config:
            # Safe Fallback to standard Cortex-M4 profile if the family is not mapped
            arch_config = {
                "arch_flags": "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard",
                "linker_prefix": mcu_short.lower()
            }
            print(f"[WARNING] Unknown architecture family {self.mcu_family}. Using Cortex-M4 flags fallback.")
        
        has_syscalls = any(f == "syscalls.c" for f in self.core_files) or os.path.exists(os.path.join(self.target_dir, "src", "bsp", "core", "syscalls.c"))
        linker_group = "-Wl,--start-group -lc -lm -Wl,--end-group"
        specs = "-specs=nano.specs"
        if not has_syscalls:
            specs += " -specs=nosys.specs"
            linker_group = "-Wl,--start-group -lc -lm -lnosys -Wl,--end-group"

        mcu_cmake_content = f"""# Microcontroller compiler & linker flags (Auto-generated by Enhanced Migrator v3)
set(LINKER_SCRIPT
    ${{PROJECT_SOURCE_DIR}}/{self.linker_script}
)
if(NOT EXISTS ${{LINKER_SCRIPT}})
    message(FATAL_ERROR "Linker script \\"${{LINKER_SCRIPT}}\\" does not exist!")
endif()

# Microcontroller architecture flags
set(MCU_ARCH_FLAGS
    {arch_config["arch_flags"]}
)

# Assembler flags
set(ASM_FLAGS
    "-x assembler-with-cpp"
)

# C compiler flags
set(C_FLAGS
    "-MMD"
    "-MP"
)

# CXX compiler flags
set(CXX_FLAGS
    "-fno-rtti"
    "-fno-exceptions"
    "-fno-threadsafe-statics"
)

# Common compilation flags
set(COMMON_FLAGS
    "-Wall"
    "-Werror"
    "-Wextra"
    "-pedantic"
    "-fdata-sections"
    "-ffunction-sections"
)

# Linker flags
set(LINKER_FLAGS
    "-T${{LINKER_SCRIPT}}"
    "{specs}"
    "-Wl,-Map=${{CMAKE_PROJECT_NAME}}.map,--cref"
    "-Wl,--gc-sections"
    "{linker_group}"
    "-Wl,--print-memory-usage"
)

# Dynamic Build optimization profiles (with LTO support)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    list(APPEND C_FLAGS "-O0" "-g3")
    list(APPEND CXX_FLAGS "-O0" "-g3")
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    list(APPEND C_FLAGS "-O3" "-flto")
    list(APPEND CXX_FLAGS "-O3" "-flto")
    list(APPEND LINKER_FLAGS "-flto")
    set_property(GLOBAL PROPERTY LTO_ENABLED TRUE)
elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    list(APPEND C_FLAGS "-Os" "-flto")
    list(APPEND CXX_FLAGS "-Os" "-flto")
    list(APPEND LINKER_FLAGS "-flto")
    set_property(GLOBAL PROPERTY LTO_ENABLED TRUE)
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    list(APPEND C_FLAGS "-O2" "-g")
    list(APPEND CXX_FLAGS "-O2" "-g")
endif()

# Joins all language-specific flags into strings
set(CMAKE_ASM_FLAGS ${{ASM_FLAGS}} ${{MCU_ARCH_FLAGS}} ${{C_FLAGS}} ${{COMMON_FLAGS}})
list(JOIN CMAKE_ASM_FLAGS " " CMAKE_ASM_FLAGS)

set(CMAKE_C_FLAGS   ${{MCU_ARCH_FLAGS}} ${{C_FLAGS}} ${{COMMON_FLAGS}})
list(JOIN CMAKE_C_FLAGS " " CMAKE_C_FLAGS)

set(CMAKE_CXX_FLAGS ${{MCU_ARCH_FLAGS}} ${{C_FLAGS}} ${{CXX_FLAGS}} ${{COMMON_FLAGS}})
list(JOIN CMAKE_CXX_FLAGS " " CMAKE_CXX_FLAGS)

set(CMAKE_EXE_LINKER_FLAGS  ${{MCU_ARCH_FLAGS}} ${{LINKER_FLAGS}})
list(JOIN CMAKE_EXE_LINKER_FLAGS " " CMAKE_EXE_LINKER_FLAGS)
"""
        mcu_cmake_file = os.path.join(self.target_dir, "cmake", "microcontrollers", f"{self.mcu_family.lower()}-gcc.cmake")
        with open(mcu_cmake_file, "w", encoding="utf-8") as f:
            f.write(mcu_cmake_content)
        print(f"Generated dynamic compilation file: cmake/microcontrollers/{self.mcu_family.lower()}-gcc.cmake")

        # Copy common.cmake
        common_cmake_file = os.path.join(self.target_dir, "cmake", "microcontrollers", "common.cmake")
        template_common_file = os.path.join(self.template_dir, "cmake", "microcontrollers", "common.cmake")
        if os.path.exists(template_common_file):
            shutil.copy(template_common_file, common_cmake_file)
            print("Copied common.cmake")

    def _generate_build_guide(self):
        print("\n--- Phase E: Generating Build Guide ---")
        project_name = os.path.basename(self.target_dir)
        mcu_define = f"{self.mcu_family}xx"
        if self.mcu_name:
            match = re.match(r'(STM32[A-Z0-9]{4})', self.mcu_name)
            if match:
                mcu_define = match.group(1) + "xx"
        
        all_core_c = [f for f in self.core_files if f.endswith(".c")]
        all_core_h = [f for f in self.core_files if f.endswith(".h")]
        all_brd_c = [f for f in self.brd_files if f.endswith(".c")]
        all_app_c = [f for f in self.app_files if f.endswith(".c")]
        
        md = f"""# {project_name} — Build Guide

Generated by `migrate_project.py` (Enhanced STM32 Migrator).

## Target Microcontroller Specifications

| Property | Value |
|----------|-------|
| MCU Family | {self.mcu_family} |
| MCU Name | {self.mcu_name or 'N/A'} |
| Chip Compile Define | `{mcu_define}` |
| Linker Script | `{self.linker_script or 'N/A'}` |
| Startup Assembly File | `{self.startup_script or 'N/A'}` |

## Compiler Setup and Prerequisites

- **CMake**: >= 3.22
- **Ninja** or **Make**
- **GNU GCC for ARM Toolchain**: (`arm-none-eabi-gcc` must be in PATH or configured via `ARM_GCC_PATH`)

```bash
# Set path manually if not present in your system variables:
export ARM_GCC_PATH=/path/to/gcc-arm-none-eabi/bin
```

## Compilation and Build Commands

```bash
# 1. Configure the workspace
cmake --preset Debug        # Compile without optimizations and full debug flags (-O0 -g3)
cmake --preset Release      # Compile with maximum speed optimization and Link-Time Optimization (-O3 -flto)
cmake --preset MinSizeRel    # Compile with maximum size optimization and Link-Time Optimization (-Os -flto)

# 2. Build executable
cmake --build --preset Debug
cmake --build --preset Release

# 3. Code formatting & linting targets
cmake --build --preset Debug --target check-format   # Verify coding standards
cmake --build --preset Debug --target run-format     # Apply auto formatting
cmake --build --preset Debug --target tidy           # Run clang-tidy
cmake --build --preset Debug --target cppcheck       # Run MISRA compliance static analyzer

# 4. Diagnostic targets
cmake --build --preset Debug --target lto-info       # Verify compiler optimization status
cmake --build --preset Debug --target size-analysis   # Display flash/ram binary footprint summary
```

## RESTURED SOURCE FILE TREE

```text
{project_name}/
├── CMakeLists.txt              # Top-level dynamic build configuration
├── CMakePresets.json            # Build presets (Debug, Release, MinSizeRel)
├── {self.linker_script or '<chip>_flash.ld'}           # Linker Script
├── cmake/
│   ├── microcontrollers/
│   │   ├── common.cmake        # Build-type optimization summaries
│   │   └── {self.mcu_family.lower()}-gcc.cmake   # Dynamic compilation and optimization flags
│   └── toolchains/
│       └── gcc-arm-none-eabi.cmake  # Cross-compiler toolchain
├── lib/
│   ├── CMakeLists.txt          # Statically compiles vendor drivers and middle-wares
│   └── CMSIS/                  # STM32 low level registers
├── scripts/
│   ├── bash/                   # POSIX Bash shell scripts (.sh)
│   ├── powershell/             # Windows native PowerShell scripts (.ps1)
│   └── monitor.py              # Serial COM monitor helper
├── src/
│   ├── main.c                  # Main program entry point
│   ├── bsp/
│   │   ├── startup/            # Assembly startup boot vectors
│   │   ├── core/               # Restructured peripheral code
│   │   └── brd/                # Restructured board buttons, LEDs, and interfaces
│   └── app/                    # Restructured user programs
└── HOW_TO_BUILD.md             # This document
```

### Core Peripheral Drivers (src/bsp/core/)
"""
        for f in all_core_c:
            md += f"- `{f}`\n"
        if all_core_h:
            md += "\n### Core Headers\n"
            for f in all_core_h:
                md += f"- `{f}`\n"
        if all_brd_c:
            md += "\n### Board/Component Interfaces (src/bsp/brd/)\n"
            for f in all_brd_c:
                md += f"- `{f}`\n"
        if all_app_c:
            md += "\n### Application Code (src/app/)\n"
            for f in all_app_c:
                md += f"- `{f}`\n"
        
        md += f"""
## HAL Configuration

The core configuration for hardware capabilities is handled by `{self.mcu_family.lower()}_hal_conf.h` in `src/bsp/core/`.
Configure peripheral features by toggling `#define HAL_*_MODULE_ENABLED` variables.

## Adding Custom C/H Source Files

1. Create files inside:
   - `src/bsp/core/` for MCU peripheral interactions.
   - `src/bsp/brd/` for external hardware driver models.
   - `src/app/` for high-level state machines and software rules.
2. Register the path to the `.c` file inside the `SOURCES_C` block of `CMakeLists.txt`.
3. Re-run building: `cmake --build --preset Debug`.
"""
        guide_path = os.path.join(self.target_dir, "HOW_TO_BUILD.md")
        with open(guide_path, "w", encoding="utf-8") as f:
            f.write(md)
        print(f"Generated build guide: HOW_TO_BUILD.md")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Enhanced STM32 Migration Script (v3) - Merges standard and LTO architectures.")
    parser.add_argument("target_dir", help="Path to the standard STM32CubeMX target folder.")
    args = parser.parse_args()

    if not os.path.isdir(args.target_dir):
        print(f"Error: Target directory '{args.target_dir}' does not exist.")
        sys.exit(1)

    migrator = CombinedSTM32Migrator(args.target_dir)
    migrator.run()
