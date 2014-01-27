_   = require 'underscore'
sd  = require('sharify').data

# requires the image mixin
module.exports =

  sizes: [
    ['small', { width: 200, height: 200}]
    ['tall', { width: 260, height: 800}]
    ['medium', { width: Infinity, height: 260}]
    ['large', { width: 640, height: 640}]
    ['larger', { width: 1024, height: 1024}]
  ]

  publicVersions: ->
    _.without(@get('image_versions'), 'normalized')

  # Given a desired width and height, return the image url that won't pixelate
  imageUrlFor: (width, height) ->
    for size in @sizes
      if width <= size[1].width && height <= size[1].height
        return @imageUrl(size[0]) if _.indexOf(@get('image_versions'), size[0]) >= 0
    return @imageUrlForMaxSize()

  imageUrlForHeight: (height) ->
    aspectRatio = @aspectRatio()
    if aspectRatio?
      @imageUrlFor height * @aspectRatio(), height
    else
      @imageUrlFor height, height

  imageUrlForWidth: (width) ->
    aspectRatio = @aspectRatio()
    if aspectRatio?
      @imageUrlFor width, (width / @aspectRatio())
    else
      @imageUrlFor width, width

  maxHeightForWidth: (width, maxDimension) ->
    aspectRatio = @aspectRatio()
    maxDimension = maxDimension || @get 'original_height'
    if aspectRatio?
      height = Math.round width / @aspectRatio()
      if height > maxDimension then maxDimension else Math.floor(height)

  maxWidthForWidth: (width, maxDimension) ->
    aspectRatio = @aspectRatio()
    if aspectRatio?
      if maxDimension
        height = width / @aspectRatio()
        height = maxDimension if height > maxDimension
        width = height * @aspectRatio()
      else
        maxDimension = @get('original_width')
      if width > maxDimension then maxDimension else Math.floor(width)

  imageUrlForMaxSize: ->
    sizes = @publicVersions()
    # favor sizes in this order
    for size in ['larger', 'large', 'tall', 'medium', 'square', 'small']
      return @imageUrl(size) if _.contains(sizes, size)
    null

  aspectRatio: -> @get('aspect_ratio')
