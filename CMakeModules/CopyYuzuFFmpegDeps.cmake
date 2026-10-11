# SPDX-FileCopyrightText: 2020 yuzu Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

function(copy_yuzu_FFmpeg_deps target_dir)
    include(WindowsCopyFiles)
    set(DLL_DEST "$<TARGET_FILE_DIR:${target_dir}>/")

    if (FFmpeg_PATH AND EXISTS "${FFmpeg_PATH}/requirements.txt")
        file(READ "${FFmpeg_PATH}/requirements.txt" FFmpeg_REQUIRED_DLLS)
        string(STRIP "${FFmpeg_REQUIRED_DLLS}" FFmpeg_REQUIRED_DLLS)
        windows_copy_files(${target_dir} ${FFmpeg_LIBRARY_DIR} ${DLL_DEST} ${FFmpeg_REQUIRED_DLLS})
    elseif (WIN32 AND FFMPEG_DIR)
        # External FFmpeg (vcpkg) does not ship the bundled requirements.txt.
        # Deploy its runtime DLLs from the installed triplet's bin directory.
        set(FFMPEG_RUNTIME_DIR "${FFMPEG_DIR}/bin")
        if (NOT IS_DIRECTORY "${FFMPEG_RUNTIME_DIR}")
            message(FATAL_ERROR "FFmpeg runtime directory missing: ${FFMPEG_RUNTIME_DIR}")
        endif()
        file(GLOB FFMPEG_RUNTIME_DLLS "${FFMPEG_RUNTIME_DIR}/*.dll")
        if (NOT FFMPEG_RUNTIME_DLLS)
            message(FATAL_ERROR "No FFmpeg runtime DLLs found in ${FFMPEG_RUNTIME_DIR}")
        endif()
        foreach(FFMPEG_DLL IN LISTS FFMPEG_RUNTIME_DLLS)
            add_custom_command(TARGET ${target_dir} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${FFMPEG_DLL}" "${DLL_DEST}"
                VERBATIM)
        endforeach()
    else()
        message(FATAL_ERROR "Unable to locate FFmpeg runtime dependencies (FFmpeg_PATH or FFMPEG_DIR)")
    endif()
endfunction(copy_yuzu_FFmpeg_deps)
