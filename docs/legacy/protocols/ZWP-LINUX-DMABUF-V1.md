NAME

       wayland::zwp_linux_dmabuf_v1_t - factory for creating dmabuf-based wl_buffers

SYNOPSIS

       #include <wayland-client-protocol-unstable.hpp>

       Inherits wayland::proxy_t.

   Public Types
       enum class wrapper_type { standard, display, foreign, proxy_wrapper }

   Public Member Functions
       zwp_linux_buffer_params_v1_t create_params ()
           create a temporary object for buffer parameters
       zwp_linux_dmabuf_feedback_v1_t get_default_feedback ()
           get default feedback
       bool can_get_default_feedback () const
           Check whether the get_default_feedback function is available with the currently bound version of the
           protocol.
       zwp_linux_dmabuf_feedback_v1_t get_surface_feedback (surface_t const &surface)
           get feedback for a surface
       bool can_get_surface_feedback () const
           Check whether the get_surface_feedback function is available with the currently bound version of the
           protocol.
       std::function< void(uint32_t)> & on_format ()
           supported buffer format
       std::function< void(uint32_t, uint32_t, uint32_t)> & on_modifier ()
           supported buffer format modifier
       uint32_t get_id () const
           Get the id of a proxy object.
       std::string get_class () const
           Get the interface name (class) of a proxy object.
       uint32_t get_version () const
           Get the protocol object version of a proxy object.
       wrapper_type get_wrapper_type () const
           Get the type of a proxy object.
       void set_queue (event_queue_t queue)
           Assign a proxy to an event queue.
       wl_proxy * c_ptr () const
           Get a pointer to the underlying C struct.
       bool proxy_has_object () const
           Check whether this wrapper actually wraps an object.
       operator bool () const
           Check whether this wrapper actually wraps an object.
       bool operator== (const proxy_t &right) const
           Check whether two wrappers refer to the same object.
       bool operator!= (const proxy_t &right) const
           Check whether two wrappers refer to different objects.
       void proxy_release ()
           Release the wrapped object (if any), making this an empty wrapper.

   Static Public Attributes
       static constexpr std::uint32_t create_params_since_version = 1
           Minimum protocol version required for the create_params function.
       static constexpr std::uint32_t get_default_feedback_since_version = 4
           Minimum protocol version required for the get_default_feedback function.
       static constexpr std::uint32_t get_surface_feedback_since_version = 4
           Minimum protocol version required for the get_surface_feedback function.

Detailed Description

       factory for creating dmabuf-based wl_buffers

       Following the interfaces from:
       https://www.khronos.org/registry/egl/extensions/EXT/EGL_EXT_image_dma_buf_import.txt
       https://www.khronos.org/registry/EGL/extensions/EXT/EGL_EXT_image_dma_buf_import_modifiers.txt and the
       Linux DRM sub-system's AddFb2 ioctl.

       This interface offers ways to create generic dmabuf-based wl_buffers.

       Clients can use the get_surface_feedback request to get dmabuf feedback for a particular surface. If the
       client wants to retrieve feedback not tied to a surface, they can use the get_default_feedback request.

       The following are required from clients:

       • Clients  must  ensure that either all data in the dma-buf is coherent for all subsequent read access or
         that coherency is correctly handled by the underlying kernel-side dma-buf implementation.

       • Don't make any more attachments after sending the buffer to the  compositor.  Making  more  attachments
         later  increases  the risk of the compositor not being able to use (re-import) an existing dmabuf-based
         wl_buffer.

       The underlying graphics stack must ensure the following:

       • The dmabuf file descriptors relayed to the server will  stay  valid  for  the  whole  lifetime  of  the
         wl_buffer.  This  means  the  server may at any time use those fds to import the dmabuf into any kernel
         sub-system that might accept it.

       However, when the underlying graphics stack fails to deliver the promise, because of e.g. a  device  hot-
       unplug  which  raises  internal  errors, after the wl_buffer has been successfully created the compositor
       must not raise protocol errors to the client when dmabuf import later fails.

       To create a wl_buffer from one or more dmabufs, a client creates a zwp_linux_dmabuf_params_v1 object with
       a zwp_linux_dmabuf_v1.create_params request. All planes required by the intended format  are  added  with
       the  'add'  request.  Finally,  a  'create'  or 'create_immed' request is issued, which has the following
       outcome depending on the import success.

       The 'create' request,

       • on success, triggers a 'created' event which provides the final wl_buffer to the client.

       • on failure, triggers a 'failed' event to convey that the server cannot use the  dmabufs  received  from
         the client.

       For the 'create_immed' request,

       • on  success,  the  server immediately imports the added dmabufs to create a wl_buffer. No event is sent
         from the server in this case.

       • on failure, the server can choose to either:

         • terminate the client by raising a fatal error.

         • mark the wl_buffer as failed, and send a 'failed' event to the client. If the client  uses  a  failed
           wl_buffer as an argument to any request, the behaviour is compositor implementation-defined.

       For  all DRM formats and unless specified in another protocol extension, pre-multiplied alpha is used for
       pixel values.

       Warning! The protocol described in this file is experimental and backward  incompatible  changes  may  be
       made.  Backward  compatible  changes may be added together with the corresponding interface version bump.
       Backward incompatible changes are done by bumping the version number in the protocol and interface  names
       and  resetting  the interface version. Once the protocol is to be declared stable, the 'z' prefix and the
       version number in the protocol and interface names are removed and the interface version number is reset.

       Definition at line 1519 of file wayland-client-protocol-unstable.hpp.

Member Enumeration Documentation

   enum class wayland::proxy_t::wrapper_type [strong],  [inherited]
       Underlying wl_proxy type and properties of a proxy_t that affect  construction,  destruction,  and  event
       handling

       Enumerator

       standard
              C pointer is a standard type compatible with wl_proxy*. Events are dispatched and it is destructed
              when the proxy_t is destructed. User data is set.

       display
              C  pointer  is  a  wl_display*. No events are dispatched, wl_display_disconnect is called when the
              proxy_t is destructed. User data is set.

       foreign
              C pointer is a standard type compatible with wl_proxy*, but another library owns it and it  should
              not  be  touched  in  a  way  that  could affect the operation of the other library. No events are
              dispatched, wl_proxy_destroy is not called when the  proxy_t  is  destructed,  user  data  is  not
              touched.  Consequently,  there is no reference counting for the proxy_t. Lifetime of such wrappers
              should preferably be short to minimize the chance that the owning library decides to  destroy  the
              wl_proxy.

       proxy_wrapper
              C  pointer  is  a  wl_proxy*  that  was  constructed  with  wl_proxy_create_wrapper. No events are
              dispatched, wl_proxy_wrapper_destroy is called when the proxy_t is destroyed.  Reference  counting
              is  active.  A reference to the proxy_t creating this proxy wrapper is held to extend its lifetime
              until after the proxy wrapper is destroyed.

       Definition at line 116 of file wayland-client.hpp.

Member Function Documentation

   wl_proxy * wayland::proxy_t::c_ptr () const [inherited]
       Get a pointer to the underlying C struct.

       Returns
           The underlying wl_proxy wrapped by this proxy_t if it exists, otherwise an exception is thrown

   bool zwp_linux_dmabuf_v1_t::can_get_default_feedback () const
       Check whether the get_default_feedback function is available with the  currently  bound  version  of  the
       protocol.

       Definition at line 5230 of file wayland-client-protocol-unstable.cpp.

   bool zwp_linux_dmabuf_v1_t::can_get_surface_feedback () const
       Check  whether  the  get_surface_feedback  function  is available with the currently bound version of the
       protocol.

       Definition at line 5242 of file wayland-client-protocol-unstable.cpp.

   zwp_linux_buffer_params_v1_t zwp_linux_dmabuf_v1_t::create_params ()
       create a temporary object for buffer parameters

       Returns
           the new temporary

       This temporary object is used to collect multiple  dmabuf  handles  into  a  single  batch  to  create  a
       wl_buffer.  It can only be used once and should be destroyed after a 'created' or 'failed' event has been
       received.

       Definition at line 5217 of file wayland-client-protocol-unstable.cpp.

   std::string wayland::proxy_t::get_class () const [inherited]
       Get the interface name (class) of a proxy object.

       Returns
           The interface name of the object associated with the proxy

   zwp_linux_dmabuf_feedback_v1_t zwp_linux_dmabuf_v1_t::get_default_feedback ()
       get default feedback This request creates a new wp_linux_dmabuf_feedback object not bound to a particular
       surface. This object will deliver feedback about dmabuf parameters to use if the client  doesn't  support
       per-surface feedback (see get_surface_feedback).

       Definition at line 5224 of file wayland-client-protocol-unstable.cpp.

   uint32_t wayland::proxy_t::get_id () const [inherited]
       Get the id of a proxy object.

       Returns
           The id the object associated with the proxy

   zwp_linux_dmabuf_feedback_v1_t zwp_linux_dmabuf_v1_t::get_surface_feedback (surface_t const & surface)
       get feedback for a surface

       Parameters
           surface

       This request creates a new wp_linux_dmabuf_feedback object for the specified wl_surface. This object will
       deliver feedback about dmabuf parameters to use for buffers attached to this surface.

       If  the  surface  is  destroyed  before  the wp_linux_dmabuf_feedback object, the feedback object becomes
       inert.

       Definition at line 5236 of file wayland-client-protocol-unstable.cpp.

   uint32_t wayland::proxy_t::get_version () const [inherited]
       Get the protocol object version of a proxy object. Gets the protocol object version of a proxy object, or
       0 if the proxy was created with unversioned API.

       A returned value of 0 means that no version information is  available,  so  the  caller  must  make  safe
       assumptions about the object's real version.

       display_t will always return version 0.

       Returns
           The protocol object version of the proxy or 0

   wrapper_type wayland::proxy_t::get_wrapper_type () const [inline],  [inherited]
       Get the type of a proxy object.

       Definition at line 302 of file wayland-client.hpp.

   std::function< void(uint32_t)> & zwp_linux_dmabuf_v1_t::on_format ()
       supported buffer format

       Parameters
           format DRM_FORMAT code

       This  event  advertises  one  buffer  format  that  the  server  supports.  All the supported formats are
       advertised once when the client binds to this interface. A roundtrip after binding  guarantees  that  the
       client has received all supported formats.

       For the definition of the format codes, see the zwp_linux_buffer_params_v1::create request.

       Starting  version  4,  the  format  event is deprecated and must not be sent by compositors. Instead, use
       get_default_feedback or get_surface_feedback.

       Definition at line 5248 of file wayland-client-protocol-unstable.cpp.

   std::function< void(uint32_t, uint32_t, uint32_t)> & zwp_linux_dmabuf_v1_t::on_modifier ()
       supported buffer format modifier

       Parameters
           format DRM_FORMAT code
           modifier_hi high 32 bits of layout modifier
           modifier_lo low 32 bits of layout modifier

       This event advertises the formats that the server supports, along with the modifiers supported  for  each
       format.  All  the  supported  modifiers for all the supported formats are advertised once when the client
       binds to this interface. A roundtrip after binding guarantees that the client has received all  supported
       format-modifier pairs.

       For  legacy  support,  DRM_FORMAT_MOD_INVALID  (that  is,  modifier_hi  ==  0x00ffffff and modifier_lo ==
       0xffffffff) is allowed in this event. It indicates that  the  server  can  support  the  format  with  an
       implicit  modifier.  When  a  plane  has  DRM_FORMAT_MOD_INVALID as its modifier, it is as if no explicit
       modifier is specified. The effective modifier will be derived from the dmabuf.

       A compositor that sends valid modifiers and DRM_FORMAT_MOD_INVALID  for  a  given  format  supports  both
       explicit modifiers and implicit modifiers.

       For  the  definition  of  the  format  and modifier codes, see the zwp_linux_buffer_params_v1::create and
       zwp_linux_buffer_params_v1::add requests.

       Starting version 4, the modifier event is deprecated and must not be sent by  compositors.  Instead,  use
       get_default_feedback or get_surface_feedback.

       Definition at line 5253 of file wayland-client-protocol-unstable.cpp.

   wayland::proxy_t::operator bool () const [inherited]
       Check whether this wrapper actually wraps an object.

       Returns
           true if there is an underlying object, false if this wrapper is empty

   bool wayland::proxy_t::operator!= (const proxy_t & right) const [inherited]
       Check whether two wrappers refer to different objects.

   bool wayland::proxy_t::operator== (const proxy_t & right) const [inherited]
       Check whether two wrappers refer to the same object.

   bool wayland::proxy_t::proxy_has_object () const [inherited]
       Check whether this wrapper actually wraps an object.

       Returns
           true if there is an underlying object, false if this wrapper is empty

   void wayland::proxy_t::proxy_release () [inherited]
       Release  the  wrapped object (if any), making this an empty wrapper. Note that display_t instances cannot
       be released this way. Attempts to do so are ignored.

       Examples
           foreign_display.cpp.

   void wayland::proxy_t::set_queue (event_queue_t queue) [inherited]
       Assign a proxy to an event queue.

       Parameters
           queue The event queue that will handle this proxy

       Assign proxy to event queue. Events coming from proxy will be queued in queue instead  of  the  display's
       main queue.

       See also: display_t::dispatch_queue().

       Examples
           proxy_wrapper.cpp.

Member Data Documentation

   constexpr    std::uint32_t    wayland::zwp_linux_dmabuf_v1_t::create_params_since_version   =   1   [static],
       [constexpr]
       Minimum protocol version required for the create_params function.

       Definition at line 1556 of file wayland-client-protocol-unstable.hpp.

   constexpr  std::uint32_t  wayland::zwp_linux_dmabuf_v1_t::get_default_feedback_since_version  =  4  [static],
       [constexpr]
       Minimum protocol version required for the get_default_feedback function.

       Definition at line 1570 of file wayland-client-protocol-unstable.hpp.

   constexpr  std::uint32_t  wayland::zwp_linux_dmabuf_v1_t::get_surface_feedback_since_version  =  4  [static],
       [constexpr]
       Minimum protocol version required for the get_surface_feedback function.

       Definition at line 1592 of file wayland-client-protocol-unstable.hpp.




/* Generated by wayland-scanner 1.11.0 */

#ifndef LINUX_DMABUF_UNSTABLE_V1_CLIENT_PROTOCOL_H
#define LINUX_DMABUF_UNSTABLE_V1_CLIENT_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>
#include "wayland-client.h"

#ifdef  __cplusplus
extern "C" {
#endif

/**
 * @page page_linux_dmabuf_unstable_v1 The linux_dmabuf_unstable_v1 protocol
 * @section page_ifaces_linux_dmabuf_unstable_v1 Interfaces
 * - @subpage page_iface_zwp_linux_dmabuf_v1 - factory for creating dmabuf-based wl_buffers
 * - @subpage page_iface_zwp_linux_buffer_params_v1 - parameters for creating a dmabuf-based wl_buffer
 * @section page_copyright_linux_dmabuf_unstable_v1 Copyright
 * <pre>
 *
 * Copyright © 2014, 2015 Collabora, Ltd.
 *
 * Permission to use, copy, modify, distribute, and sell this
 * software and its documentation for any purpose is hereby granted
 * without fee, provided that the above copyright notice appear in
 * all copies and that both that copyright notice and this permission
 * notice appear in supporting documentation, and that the name of
 * the copyright holders not be used in advertising or publicity
 * pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no
 * representations about the suitability of this software for any
 * purpose.  It is provided "as is" without express or implied
 * warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
 * SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
 * ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
 * THIS SOFTWARE.
 * </pre>
 */
struct wl_buffer;
struct zwp_linux_buffer_params_v1;
struct zwp_linux_dmabuf_v1;

/**
 * @page page_iface_zwp_linux_dmabuf_v1 zwp_linux_dmabuf_v1
 * @section page_iface_zwp_linux_dmabuf_v1_desc Description
 *
 * Following the interfaces from:
 * https://www.khronos.org/registry/egl/extensions/EXT/EGL_EXT_image_dma_buf_import.txt
 * and the Linux DRM sub-system's AddFb2 ioctl.
 *
 * This interface offers a way to create generic dmabuf-based
 * wl_buffers. Immediately after a client binds to this interface,
 * the set of supported formats is sent with 'format' events.
 *
 * The following are required from clients:
 *
 * - Clients must ensure that either all data in the dma-buf is
 * coherent for all subsequent read access or that coherency is
 * correctly handled by the underlying kernel-side dma-buf
 * implementation.
 *
 * - Don't make any more attachments after sending the buffer to the
 * compositor. Making more attachments later increases the risk of
 * the compositor not being able to use (re-import) an existing
 * dmabuf-based wl_buffer.
 *
 * The underlying graphics stack must ensure the following:
 *
 * - The dmabuf file descriptors relayed to the server will stay valid
 * for the whole lifetime of the wl_buffer. This means the server may
 * at any time use those fds to import the dmabuf into any kernel
 * sub-system that might accept it.
 *
 * To create a wl_buffer from one or more dmabufs, a client creates a
 * zwp_linux_dmabuf_params_v1 object with a zwp_linux_dmabuf_v1.create_params
 * request. All planes required by the intended format are added with
 * the 'add' request. Finally, a 'create' request is issued. The server
 * will reply with either a 'created' event which provides the final
 * wl_buffer or a 'failed' event saying that it cannot use the dmabufs
 * provided.
 *
 * Warning! The protocol described in this file is experimental and
 * backward incompatible changes may be made. Backward compatible changes
 * may be added together with the corresponding interface version bump.
 * Backward incompatible changes are done by bumping the version number in
 * the protocol and interface names and resetting the interface version.
 * Once the protocol is to be declared stable, the 'z' prefix and the
 * version number in the protocol and interface names are removed and the
 * interface version number is reset.
 * @section page_iface_zwp_linux_dmabuf_v1_api API
 * See @ref iface_zwp_linux_dmabuf_v1.
 */
/**
 * @defgroup iface_zwp_linux_dmabuf_v1 The zwp_linux_dmabuf_v1 interface
 *
 * Following the interfaces from:
 * https://www.khronos.org/registry/egl/extensions/EXT/EGL_EXT_image_dma_buf_import.txt
 * and the Linux DRM sub-system's AddFb2 ioctl.
 *
 * This interface offers a way to create generic dmabuf-based
 * wl_buffers. Immediately after a client binds to this interface,
 * the set of supported formats is sent with 'format' events.
 *
 * The following are required from clients:
 *
 * - Clients must ensure that either all data in the dma-buf is
 * coherent for all subsequent read access or that coherency is
 * correctly handled by the underlying kernel-side dma-buf
 * implementation.
 *
 * - Don't make any more attachments after sending the buffer to the
 * compositor. Making more attachments later increases the risk of
 * the compositor not being able to use (re-import) an existing
 * dmabuf-based wl_buffer.
 *
 * The underlying graphics stack must ensure the following:
 *
 * - The dmabuf file descriptors relayed to the server will stay valid
 * for the whole lifetime of the wl_buffer. This means the server may
 * at any time use those fds to import the dmabuf into any kernel
 * sub-system that might accept it.
 *
 * To create a wl_buffer from one or more dmabufs, a client creates a
 * zwp_linux_dmabuf_params_v1 object with a zwp_linux_dmabuf_v1.create_params
 * request. All planes required by the intended format are added with
 * the 'add' request. Finally, a 'create' request is issued. The server
 * will reply with either a 'created' event which provides the final
 * wl_buffer or a 'failed' event saying that it cannot use the dmabufs
 * provided.
 *
 * Warning! The protocol described in this file is experimental and
 * backward incompatible changes may be made. Backward compatible changes
 * may be added together with the corresponding interface version bump.
 * Backward incompatible changes are done by bumping the version number in
 * the protocol and interface names and resetting the interface version.
 * Once the protocol is to be declared stable, the 'z' prefix and the
 * version number in the protocol and interface names are removed and the
 * interface version number is reset.
 */
extern const struct wl_interface zwp_linux_dmabuf_v1_interface;
/**
 * @page page_iface_zwp_linux_buffer_params_v1 zwp_linux_buffer_params_v1
 * @section page_iface_zwp_linux_buffer_params_v1_desc Description
 *
 * This temporary object is a collection of dmabufs and other
 * parameters that together form a single logical buffer. The temporary
 * object may eventually create one wl_buffer unless cancelled by
 * destroying it before requesting 'create'.
 *
 * Single-planar formats only require one dmabuf, however
 * multi-planar formats may require more than one dmabuf. For all
 * formats, an 'add' request must be called once per plane (even if the
 * underlying dmabuf fd is identical).
 *
 * You must use consecutive plane indices ('plane_idx' argument for 'add')
 * from zero to the number of planes used by the drm_fourcc format code.
 * All planes required by the format must be given exactly once, but can
 * be given in any order. Each plane index can be set only once.
 * @section page_iface_zwp_linux_buffer_params_v1_api API
 * See @ref iface_zwp_linux_buffer_params_v1.
 */
/**
 * @defgroup iface_zwp_linux_buffer_params_v1 The zwp_linux_buffer_params_v1 interface
 *
 * This temporary object is a collection of dmabufs and other
 * parameters that together form a single logical buffer. The temporary
 * object may eventually create one wl_buffer unless cancelled by
 * destroying it before requesting 'create'.
 *
 * Single-planar formats only require one dmabuf, however
 * multi-planar formats may require more than one dmabuf. For all
 * formats, an 'add' request must be called once per plane (even if the
 * underlying dmabuf fd is identical).
 *
 * You must use consecutive plane indices ('plane_idx' argument for 'add')
 * from zero to the number of planes used by the drm_fourcc format code.
 * All planes required by the format must be given exactly once, but can
 * be given in any order. Each plane index can be set only once.
 */
extern const struct wl_interface zwp_linux_buffer_params_v1_interface;

/**
 * @ingroup iface_zwp_linux_dmabuf_v1
 * @struct zwp_linux_dmabuf_v1_listener
 */
struct zwp_linux_dmabuf_v1_listener {
	/**
	 * supported buffer format
	 *
	 * This event advertises one buffer format that the server
	 * supports. All the supported formats are advertised once when the
	 * client binds to this interface. A roundtrip after binding
	 * guarantees that the client has received all supported formats.
	 *
	 * For the definition of the format codes, see create request.
	 *
	 * XXX: Can a compositor ever enumerate them?
	 * @param format DRM_FORMAT code
	 */
	void (*format)(void *data,
		       struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1,
		       uint32_t format);
};

/**
 * @ingroup zwp_linux_dmabuf_v1_iface
 */
static inline int
zwp_linux_dmabuf_v1_add_listener(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1,
				 const struct zwp_linux_dmabuf_v1_listener *listener, void *data)
{
	return wl_proxy_add_listener((struct wl_proxy *) zwp_linux_dmabuf_v1,
				     (void (**)(void)) listener, data);
}

#define ZWP_LINUX_DMABUF_V1_DESTROY	0
#define ZWP_LINUX_DMABUF_V1_CREATE_PARAMS	1

/**
 * @ingroup iface_zwp_linux_dmabuf_v1
 */
#define ZWP_LINUX_DMABUF_V1_DESTROY_SINCE_VERSION	1
/**
 * @ingroup iface_zwp_linux_dmabuf_v1
 */
#define ZWP_LINUX_DMABUF_V1_CREATE_PARAMS_SINCE_VERSION	1

/** @ingroup iface_zwp_linux_dmabuf_v1 */
static inline void
zwp_linux_dmabuf_v1_set_user_data(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1, void *user_data)
{
	wl_proxy_set_user_data((struct wl_proxy *) zwp_linux_dmabuf_v1, user_data);
}

/** @ingroup iface_zwp_linux_dmabuf_v1 */
static inline void *
zwp_linux_dmabuf_v1_get_user_data(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1)
{
	return wl_proxy_get_user_data((struct wl_proxy *) zwp_linux_dmabuf_v1);
}

static inline uint32_t
zwp_linux_dmabuf_v1_get_version(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1)
{
	return wl_proxy_get_version((struct wl_proxy *) zwp_linux_dmabuf_v1);
}

/**
 * @ingroup iface_zwp_linux_dmabuf_v1
 *
 * Objects created through this interface, especially wl_buffers, will
 * remain valid.
 */
static inline void
zwp_linux_dmabuf_v1_destroy(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1)
{
	wl_proxy_marshal((struct wl_proxy *) zwp_linux_dmabuf_v1,
			 ZWP_LINUX_DMABUF_V1_DESTROY);

	wl_proxy_destroy((struct wl_proxy *) zwp_linux_dmabuf_v1);
}

/**
 * @ingroup iface_zwp_linux_dmabuf_v1
 *
 * This temporary object is used to collect multiple dmabuf handles into
 * a single batch to create a wl_buffer. It can only be used once and
 * should be destroyed after a 'created' or 'failed' event has been
 * received.
 */
static inline struct zwp_linux_buffer_params_v1 *
zwp_linux_dmabuf_v1_create_params(struct zwp_linux_dmabuf_v1 *zwp_linux_dmabuf_v1)
{
	struct wl_proxy *params_id;

	params_id = wl_proxy_marshal_constructor((struct wl_proxy *) zwp_linux_dmabuf_v1,
			 ZWP_LINUX_DMABUF_V1_CREATE_PARAMS, &zwp_linux_buffer_params_v1_interface, NULL);

	return (struct zwp_linux_buffer_params_v1 *) params_id;
}

#ifndef ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ENUM
#define ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ENUM
enum zwp_linux_buffer_params_v1_error {
	/**
	 * the dmabuf_batch object has already been used to create a wl_buffer
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ALREADY_USED = 0,
	/**
	 * plane index out of bounds
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_PLANE_IDX = 1,
	/**
	 * the plane index was already set
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_PLANE_SET = 2,
	/**
	 * missing or too many planes to create a buffer
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_INCOMPLETE = 3,
	/**
	 * format not supported
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_INVALID_FORMAT = 4,
	/**
	 * invalid width or height
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_INVALID_DIMENSIONS = 5,
	/**
	 * offset + stride * height goes out of dmabuf bounds
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_OUT_OF_BOUNDS = 6,
};
#endif /* ZWP_LINUX_BUFFER_PARAMS_V1_ERROR_ENUM */

#ifndef ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_ENUM
#define ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_ENUM
enum zwp_linux_buffer_params_v1_flags {
	/**
	 * contents are y-inverted
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_Y_INVERT = 1,
	/**
	 * content is interlaced
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_INTERLACED = 2,
	/**
	 * bottom field first
	 */
	ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_BOTTOM_FIRST = 4,
};
#endif /* ZWP_LINUX_BUFFER_PARAMS_V1_FLAGS_ENUM */

/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 * @struct zwp_linux_buffer_params_v1_listener
 */
struct zwp_linux_buffer_params_v1_listener {
	/**
	 * buffer creation succeeded
	 *
	 * This event indicates that the attempted buffer creation was
	 * successful. It provides the new wl_buffer referencing the
	 * dmabuf(s).
	 *
	 * Upon receiving this event, the client should destroy the
	 * zlinux_dmabuf_params object.
	 * @param buffer the newly created wl_buffer
	 */
	void (*created)(void *data,
			struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1,
			struct wl_buffer *buffer);
	/**
	 * buffer creation failed
	 *
	 * This event indicates that the attempted buffer creation has
	 * failed. It usually means that one of the dmabuf constraints has
	 * not been fulfilled.
	 *
	 * Upon receiving this event, the client should destroy the
	 * zlinux_buffer_params object.
	 */
	void (*failed)(void *data,
		       struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1);
};

/**
 * @ingroup zwp_linux_buffer_params_v1_iface
 */
static inline int
zwp_linux_buffer_params_v1_add_listener(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1,
					const struct zwp_linux_buffer_params_v1_listener *listener, void *data)
{
	return wl_proxy_add_listener((struct wl_proxy *) zwp_linux_buffer_params_v1,
				     (void (**)(void)) listener, data);
}

#define ZWP_LINUX_BUFFER_PARAMS_V1_DESTROY	0
#define ZWP_LINUX_BUFFER_PARAMS_V1_ADD	1
#define ZWP_LINUX_BUFFER_PARAMS_V1_CREATE	2

/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 */
#define ZWP_LINUX_BUFFER_PARAMS_V1_DESTROY_SINCE_VERSION	1
/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 */
#define ZWP_LINUX_BUFFER_PARAMS_V1_ADD_SINCE_VERSION	1
/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 */
#define ZWP_LINUX_BUFFER_PARAMS_V1_CREATE_SINCE_VERSION	1

/** @ingroup iface_zwp_linux_buffer_params_v1 */
static inline void
zwp_linux_buffer_params_v1_set_user_data(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1, void *user_data)
{
	wl_proxy_set_user_data((struct wl_proxy *) zwp_linux_buffer_params_v1, user_data);
}

/** @ingroup iface_zwp_linux_buffer_params_v1 */
static inline void *
zwp_linux_buffer_params_v1_get_user_data(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1)
{
	return wl_proxy_get_user_data((struct wl_proxy *) zwp_linux_buffer_params_v1);
}

static inline uint32_t
zwp_linux_buffer_params_v1_get_version(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1)
{
	return wl_proxy_get_version((struct wl_proxy *) zwp_linux_buffer_params_v1);
}

/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 *
 * Cleans up the temporary data sent to the server for dmabuf-based
 * wl_buffer creation.
 */
static inline void
zwp_linux_buffer_params_v1_destroy(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1)
{
	wl_proxy_marshal((struct wl_proxy *) zwp_linux_buffer_params_v1,
			 ZWP_LINUX_BUFFER_PARAMS_V1_DESTROY);

	wl_proxy_destroy((struct wl_proxy *) zwp_linux_buffer_params_v1);
}

/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 *
 * This request adds one dmabuf to the set in this
 * zwp_linux_buffer_params_v1.
 *
 * The 64-bit unsigned value combined from modifier_hi and modifier_lo
 * is the dmabuf layout modifier. DRM AddFB2 ioctl calls this the
 * fb modifier, which is defined in drm_mode.h of Linux UAPI.
 * This is an opaque token. Drivers use this token to express tiling,
 * compression, etc. driver-specific modifications to the base format
 * defined by the DRM fourcc code.
 *
 * This request raises the PLANE_IDX error if plane_idx is too large.
 * The error PLANE_SET is raised if attempting to set a plane that
 * was already set.
 */
static inline void
zwp_linux_buffer_params_v1_add(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1, int32_t fd, uint32_t plane_idx, uint32_t offset, uint32_t stride, uint32_t modifier_hi, uint32_t modifier_lo)
{
	wl_proxy_marshal((struct wl_proxy *) zwp_linux_buffer_params_v1,
			 ZWP_LINUX_BUFFER_PARAMS_V1_ADD, fd, plane_idx, offset, stride, modifier_hi, modifier_lo);
}

/**
 * @ingroup iface_zwp_linux_buffer_params_v1
 *
 * This asks for creation of a wl_buffer from the added dmabuf
 * buffers. The wl_buffer is not created immediately but returned via
 * the 'created' event if the dmabuf sharing succeeds. The sharing
 * may fail at runtime for reasons a client cannot predict, in
 * which case the 'failed' event is triggered.
 *
 * The 'format' argument is a DRM_FORMAT code, as defined by the
 * libdrm's drm_fourcc.h. The Linux kernel's DRM sub-system is the
 * authoritative source on how the format codes should work.
 *
 * The 'flags' is a bitfield of the flags defined in enum "flags".
 * 'y_invert' means the that the image needs to be y-flipped.
 *
 * Flag 'interlaced' means that the frame in the buffer is not
 * progressive as usual, but interlaced. An interlaced buffer as
 * supported here must always contain both top and bottom fields.
 * The top field always begins on the first pixel row. The temporal
 * ordering between the two fields is top field first, unless
 * 'bottom_first' is specified. It is undefined whether 'bottom_first'
 * is ignored if 'interlaced' is not set.
 *
 * This protocol does not convey any information about field rate,
 * duration, or timing, other than the relative ordering between the
 * two fields in one buffer. A compositor may have to estimate the
 * intended field rate from the incoming buffer rate. It is undefined
 * whether the time of receiving wl_surface.commit with a new buffer
 * attached, applying the wl_surface state, wl_surface.frame callback
 * trigger, presentation, or any other point in the compositor cycle
 * is used to measure the frame or field times. There is no support
 * for detecting missed or late frames/fields/buffers either, and
 * there is no support whatsoever for cooperating with interlaced
 * compositor output.
 *
 * The composited image quality resulting from the use of interlaced
 * buffers is explicitly undefined. A compositor may use elaborate
 * hardware features or software to deinterlace and create progressive
 * output frames from a sequence of interlaced input buffers, or it
 * may produce substandard image quality. However, compositors that
 * cannot guarantee reasonable image quality in all cases are recommended
 * to just reject all interlaced buffers.
 *
 * Any argument errors, including non-positive width or height,
 * mismatch between the number of planes and the format, bad
 * format, bad offset or stride, may be indicated by fatal protocol
 * errors: INCOMPLETE, INVALID_FORMAT, INVALID_DIMENSIONS,
 * OUT_OF_BOUNDS.
 *
 * Dmabuf import errors in the server that are not obvious client
 * bugs are returned via the 'failed' event as non-fatal. This
 * allows attempting dmabuf sharing and falling back in the client
 * if it fails.
 *
 * This request can be sent only once in the object's lifetime, after
 * which the only legal request is destroy. This object should be
 * destroyed after issuing a 'create' request. Attempting to use this
 * object after issuing 'create' raises ALREADY_USED protocol error.
 *
 * It is not mandatory to issue 'create'. If a client wants to
 * cancel the buffer creation, it can just destroy this object.
 */
static inline void
zwp_linux_buffer_params_v1_create(struct zwp_linux_buffer_params_v1 *zwp_linux_buffer_params_v1, int32_t width, int32_t height, uint32_t format, uint32_t flags)
{
	wl_proxy_marshal((struct wl_proxy *) zwp_linux_buffer_params_v1,
			 ZWP_LINUX_BUFFER_PARAMS_V1_CREATE, width, height, format, flags);
}

#ifdef  __cplusplus
}
#endif

#endif