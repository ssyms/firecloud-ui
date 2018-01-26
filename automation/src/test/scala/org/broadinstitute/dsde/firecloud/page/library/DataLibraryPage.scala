package org.broadinstitute.dsde.firecloud.page.library


import org.broadinstitute.dsde.firecloud.component._
import org.broadinstitute.dsde.firecloud.component.Component._
import org.broadinstitute.dsde.workbench.config.Config
import org.broadinstitute.dsde.firecloud.page.{BaseFireCloudPage, PageUtil}
import org.broadinstitute.dsde.workbench.service.util.Retry.retry
import org.openqa.selenium.WebDriver
import org.scalatest.selenium.Page

import scala.concurrent.duration.DurationLong

/**
  * Page class for the Data Library page.
  */
class DataLibraryPage(implicit webDriver: WebDriver) extends BaseFireCloudPage
  with Page with PageUtil[DataLibraryPage] {
  override val url: String = s"${Config.FireCloud.baseUrl}#library"

  private val LibraryTable = Table("library-table")
  private val searchField = SearchField("library-search-input")
  private val rpModalLink = Link("show-research-purpose-modal")
  private val rpModalTitleLabel = Label("research-purpose-modal-title")
  private val rpDismissButton = Button("x-button")
  private val rpSearchButton = Button("ok-button")
  private val tags = Tags("tags")
  private val consentCodes = Tags("consent-codes")

  override def awaitReady: Unit = {
    LibraryTable.awaitReady()
  }

  def validateLocation(): Unit = {
    LibraryTable.awaitReady()
  }

  def hasDataset(name: String): Boolean = {
    doSearch(name)
    Link(s"dataset-$name").isVisible
  }

  def waitForDataset(name:String) = {
    retry[DataLibraryPage](10.seconds, 5.minutes)({
      val libraryPage = open
      if (libraryPage.hasDataset(name))
        Some(libraryPage)
      else None
    })
  }

  def doSearch(searchParameter: String): Unit = {
    searchField.setText(searchParameter)
    pressKeys("\n")
    LibraryTable.awaitReady()
  }

  def openResearchPurposeModal(): Unit = {
    rpModalLink.doClick()
  }

  def dismissResearchPurposeModal(): Unit = {
    rpDismissButton.doClick()
  }

  def isShowingResearchPurposeModal: Boolean = {
    rpModalTitleLabel.isVisible
  }

  def selectRPCheckbox(code: String): Unit = {
    Checkbox(s"$code-checkbox").ensureChecked()
  }

  def executeRPSearch(): Unit = {
    rpSearchButton.doClick()
  }

  def getConsentCodes(): Seq[String] = {
    consentCodes.awaitVisible()
    consentCodes.getTags
  }

  def getTags(): Seq[String] = {
    tags.awaitVisible()
    tags.getTags
  }

}
