{ pick, extend } = require 'underscore'
Backbone = require 'backbone'
qs = require 'qs'
User = require '../../../../models/user.coffee'
Artwork = require '../../../../models/artwork.coffee'
CurrentUser = require '../../../../models/current_user.coffee'
Fair = require '../../../../models/fair.coffee'
ArtworkInquiry = require '../../../../models/artwork_inquiry.coffee'
Form = require '../../../../components/form/index.coffee'
Serializer = require '../../../../components/form/serializer.coffee'
analyticsHooks = require '../../../../lib/analytics_hooks.coffee'
openMultiPageModal = require '../../../../components/multi_page_modal/index.coffee'
openInquiryQuestionnaireFor = require '../../../../components/inquiry_questionnaire/index.coffee'
splitTest = require '../../../../components/split_test/index.coffee'
AuthModalView = require '../../../../../desktop/components/auth_modal/view.coffee'
sd = require('sharify').data
template = -> require('./templates/index.jade') arguments...
confirmation = -> require('./templates/confirmation.jade') arguments...
{ createOrder } = require '../../../../../lib/components/create_order'
{ createOfferOrder } = require '../../../../../lib/components/create_offer_order'
inquireSpecialist = require '../../lib/inquire.coffee'
errorModal = require '../../client/errorModal'
mediator = require '../../../../lib/mediator.coffee'

module.exports = class ArtworkCommercialView extends Backbone.View
  tagName: 'form'
  className: 'artwork-commercial'

  events:
    'click .js-artwork-inquire-button'      : 'inquire'
    'click .js-artwork-acquire-button'      : 'acquire'
    'click .js-artwork-offer-button'        : 'offer'
    'click .collector-faq'                  : 'openCollectorModal'
    'click .js-artwork-bnmo-collector-faq'  : 'trackOpenCollectorFAQ'
    'click .js-artwork-bnmo-ask-specialist' : 'inquireSpecialist'

  initialize: ({ @data }) ->
    { artwork } = @data

    @artwork = new Artwork artwork

    if CurrentUser.orNull() and
        qs.parse(location.search.substring(1)).inquire is 'true'
      @inquire()

  inquireSpecialist: (e) ->
    e.preventDefault()
    analytics.track('Click', {
      subject: 'ask a specialist',
      type: 'button',
      flow: 'buy now'
    })
    inquireSpecialist @artwork.get('_id'), ask_specialist: true

  acquire: (e) ->
    e.preventDefault()

    loggedInUser = CurrentUser.orNull()

    analytics.track('Click', {
      subject: 'buy',
      type: 'button',
      flow: 'buy now'
    })

    serializer = new Serializer @$('form')
    data = serializer.data()
    editionSetId = data.edition_set_id
    $target = $(e.currentTarget)

    # If this artwork has an edition set of 1, send that in the mutation as well
    if @artwork.get('edition_sets')?.length && @artwork.get('edition_sets').length == 1
      editionSetId = @artwork.get('edition_sets')[0] && @artwork.get('edition_sets')[0].id

    if loggedInUser
      $target.attr 'data-state', 'loading'
      createOrder
        artworkId: @artwork.get('_id')
        editionSetId: editionSetId
        quantity: 1
        user: loggedInUser
      .then (data) ->
        { order, error } = data?.ecommerceCreateOrderWithArtwork?.orderOrError || {}
        if order
          analytics.track('created_order', { order_id: order.id })
          location.assign("/orders/#{order.id}/shipping")
        else
          console.error('createOrder', error)
          $target.attr 'data-state', 'loaded'
          errorModal.renderBuyNowError(error)
      .catch (err) ->
        console.error('createOrder', err)
        $target.attr 'data-state', 'loaded'
        errorModal.render()
    else
      return mediator.trigger 'open:auth',
        intent: 'buy now'
        signupIntent: 'buy now'
        mode: 'login'
        trigger: 'click'
        redirectTo: location.href

  offer: (e) ->
    e.preventDefault()

    loggedInUser = CurrentUser.orNull()

    serializer = new Serializer @$('form')
    data = serializer.data()
    editionSetId = data.edition_set_id
    $target = $(e.currentTarget)

    # If this artwork has an edition set of 1, send that in the mutation as well
    if @artwork.get('edition_sets')?.length && @artwork.get('edition_sets').length == 1
      editionSetId = @artwork.get('edition_sets')[0] && @artwork.get('edition_sets')[0].id

    if loggedInUser
      $target.attr 'data-state', 'loading'
      createOfferOrder
        artworkId: @artwork.get('_id')
        editionSetId: editionSetId
        quantity: 1
        user: loggedInUser
      .then (data) ->
        { order, error } = data?.ecommerceCreateOfferOrderWithArtwork?.orderOrError || {}
        if order
          location.assign("/orders/#{order.id}/offer")
        else
          console.error('createOfferOrder', error)
          $target.attr 'data-state', 'loaded'
          errorModal.renderBuyNowError(error)
      .catch (err) ->
        console.error('createOfferOrder', err)
        $target.attr 'data-state', 'loaded'
        errorModal.render()
    else
      return mediator.trigger 'open:auth',
        intent: 'make offer'
        signupIntent: 'make offer'
        mode: 'login'
        trigger: 'click'
        redirectTo: location.href

  inquire: (e) =>
    e.preventDefault() if e

    @user = User.instantiate()

    if @user.isLoggedOut() && sd.COMMERCIAL?.enableNewInquiryFlow
      redirectTo = "#{location.pathname}#{location.search or "?"}&inquire=true"
      @modal = new AuthModalView { width: '500px', redirectTo }
    else
      @inquiry = new ArtworkInquiry notification_delay: 600

      form = new Form model: @inquiry, $form: @$('form')
      return unless form.isReady()

      form.state 'loading'

      { attending } = data = form.serializer.data()
      @user.set pick data, 'name', 'email'
      @inquiry.set data
      if attending
        @user.related()
          .collectorProfile.related()
          .userFairActions
          .attendFair @data.artwork.fair

      @artwork.fetch().then =>
        @artwork.related().fairs.add @data.artwork.fair
        @modal = openInquiryQuestionnaireFor
          user: @user
          artwork: @artwork
          inquiry: @inquiry

        # Stop the spinner once the modal opens
        @listenToOnce @modal.view, 'opened', ->
          form.state 'default'

        # Abort or error
        @listenToOnce @modal.view, 'closed', ->
          form.reenable true

        # Success
        @listenToOnce @inquiry, 'sync', =>
          @$('.js-artwork-inquiry-form')
            .html confirmation()

  openCollectorModal: (e) ->
    e.preventDefault()
    openMultiPageModal 'collector-faqs'

  trackOpenCollectorFAQ: (e) ->
    analytics.track('Click', {
      subject: 'read faq',
      type: 'button',
      flow: 'buy now'
    })

  render: ->
    if @data.artwork.fair
      fair = new Fair @data.artwork.fair
    html = template extend @data, { fair },
      helpers: extend [
        {}
        commercial: require './helpers.coffee'
        partner_stub: require '../partner_stub/helpers.coffee'
      ]...
    @$el.html $(html)
    this
