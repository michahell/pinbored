package nl.powergeek.pinbored.screens
{
	import feathers.controls.Button;
	import feathers.controls.Callout;
	import feathers.controls.Header;
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.controls.List;
	import feathers.controls.Panel;
	import feathers.controls.Screen;
	import feathers.controls.ScrollContainer;
	import feathers.controls.TextInput;
	import feathers.controls.renderers.BaseDefaultItemRenderer;
	import feathers.controls.renderers.IListItemRenderer;
	import feathers.controls.text.TextFieldTextRenderer;
	import feathers.core.ITextRenderer;
	import feathers.data.ListCollection;
	import feathers.events.FeathersEventType;
	import feathers.layout.AnchorLayoutData;
	import feathers.layout.HorizontalLayout;
	import feathers.layout.VerticalLayout;
	
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.text.TextFormat;
	import flash.utils.setTimeout;
	
	import nl.powergeek.REST.RESTClient;
	import nl.powergeek.REST.RESTRequest;
	import nl.powergeek.feathers.components.AppScreen;
	import nl.powergeek.feathers.components.Pager;
	import nl.powergeek.feathers.components.PinboardLayoutGroupItemRenderer;
	import nl.powergeek.feathers.components.PinboredHeader;
	import nl.powergeek.feathers.components.Tag;
	import nl.powergeek.feathers.components.TagTextInput;
	import nl.powergeek.feathers.themes.PinboredDesktopTheme;
	import nl.powergeek.pinbored.model.AppModel;
	import nl.powergeek.pinbored.model.BookMark;
	import nl.powergeek.pinbored.model.BookmarkEvent;
	import nl.powergeek.pinbored.services.PinboardService;
	import nl.powergeek.utils.ArrayCollectionPager;
	
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;
	import org.osmf.layout.HorizontalAlign;
	
	import starling.animation.Tween;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.Quad;
	import starling.events.Event;
	import starling.events.ResizeEvent;
	import starling.textures.Texture;
	
	public class ListScreen extends AppScreen
	{
		// GUI related
		private var 
			panel:Panel = new Panel(),
			searchTags:TagTextInput,
			pagingControl:Pager,
			listScrollContainer:ScrollContainer,
			list:List = new List(),
			_backgroundImage:Image = new Image(Texture.fromBitmap(new PinboredDesktopTheme.BACKGROUND2(), false)),
			_panelExcludedSpace:uint = 0;
		
		private var
			_onLoginScreenRequest:Signal = new Signal( ListScreen );
		
		public function ListScreen()
		{
			super();
		}
		
		override protected function initialize():void
		{
			// create GUI
			createGUI();
			
			// listen for transition complete
			owner.addEventListener(FeathersEventType.TRANSITION_COMPLETE, onTransitionComplete);
		}
		
		private function onTransitionComplete(event:starling.events.Event):void
		{
			// remove listener
			owner.removeEventListener(FeathersEventType.TRANSITION_COMPLETE, onTransitionComplete);
			
			// setup list delete listener
			list.addEventListener(BookmarkEvent.BOOKMARK_DELETED, function(event:starling.events.Event):void {
				trace('receiving BOOKMARK_DELETED event from custom item renderer...');
				var deletedBookmark:BookMark = BookMark(event.data);
				removeBookmarkFromList(deletedBookmark);
			});
			
			list.addEventListener(BookmarkEvent.BOOKMARK_COLLAPSING, function(event:starling.events.Event):void {
				trace('receiving BOOKMARK_COLLAPSING event from custom item renderer...');
				var collapsedBookmark:BookMark = BookMark(event.data);
				// TODO stuff with collapsing bookmark
			});
			
			list.addEventListener(BookmarkEvent.BOOKMARK_FOLDING, function(event:starling.events.Event):void {
				trace('receiving BOOKMARK_FOLDING event from custom item renderer...');
				var foldedBookmark:BookMark = BookMark(event.data);
				// TODO stuff with folding bookmark
			});
			
			// when searched for tags, update the bookmarks list
			searchTags.searchTagsTriggered.add(function(tagNames:Vector.<String>):void {
				
				// show loading icon
				showLoading();
				
				AppModel.rawBookmarkDataListFiltered = PinboardService.filterTags(AppModel.rawBookmarkDataList, tagNames);
				trace('done filtering: ' + AppModel.rawBookmarkDataListFiltered.length);
				
				// show loading icon
				setTimeout(function():void {
					hideLoading();
				}, 1000);
				
				if(AppModel.rawBookmarkDataListFiltered.length > 0) {
					trace('called!');
					displayInitialResultsPage(AppModel.rawBookmarkDataListFiltered);
				} else {
					trace('no results after filtering...');
					cleanBookmarkList();
				}
			});
			
			// TODO listen to paging bar events and call displayNext / displayPrevious functions?
			
			
			
			// get all bookmarks and populate list control
			getInitialData();
		}
		
		private function getInitialData():void
		{
			// throw all bookmarks into a list
			PinboardService.allBookmarksReceived.addOnce(function(event:flash.events.Event):void {
				
				var parsedResponse:Object = JSON.parse(event.target.data as String);
				
				parsedResponse.forEach(function(bookmark:Object, index:int, array:Array):void {
					AppModel.rawBookmarkDataList.push(bookmark);
				});
				
				displayInitialResultsPage(AppModel.rawBookmarkDataList);
				
				// hide loading icon
				setTimeout(function():void {
					hideLoading();
				}, 1000);
			});
			
			// show loading icon
			showLoading();
			
			// get all bookmarks
			PinboardService.GetAllBookmarks();
		}
		
		private function cleanBookmarkList():void {
			
			// first, remove all listeners from old bookmarksList
			AppModel.bookmarksList.forEach(function(bm:BookMark, index:uint, array:Array):void {
				bm.editTapped..removeAll();
				bm.deleteTapped.removeAll();
				bm.staleConfirmed.removeAll();
				bm.notStaleConfirmed.removeAll();
			});
				
			// then, null the dataprovider for refresh
			list.dataProvider = null;
		}
		
		private function activateBookmarkList():void {
			
			// attach listeners to each bookmark in the bookmarkslist
			AppModel.bookmarksList.forEach(function(bm:BookMark, index:uint, array:Array):void {
				
				// if bookmark DELETE is tapped
				bm.deleteTapped.addOnce(function(tappedBookmark:BookMark):void{
					trace('bookmark delete tapped!');
					// execute request and attach listener to returned signal
					var returnSignal:Signal = PinboardService.deleteBookmark(tappedBookmark);
					returnSignal.addOnce(function():void{
						trace('bookmark delete request completed.');
						// update the bookmark by confirming delete
						tappedBookmark.deleteConfirmed.dispatch();
					});
					
					// MOCK CONFIRMATION!!
					setTimeout(function():void{
						tappedBookmark.deleteConfirmed.dispatch();
						trace('dispatching delete...');
					}, Math.random() * 1000);
				});
				
			});
			
			// update the list's dataprovider
			list.dataProvider = new ListCollection(AppModel.bookmarksList);
		}
		
		private function displayInitialResultsPage(array:Array):void
		{
			// first, page raw bookmark results (this list can be huge)
			AppModel.rawBookmarkListCollectionPager = new ArrayCollectionPager(array, AppModel.BOOKMARKS_PER_PAGE);
			
			// create buttons for all result pages
			var resultPages:Number = AppModel.rawBookmarkListCollectionPager.numPages;
			
			// if we have result pages
			if(resultPages > 0) {
				trace('we have result pages!');
				// make paging control visible and add padding
				pagingControl.visible = true;
				pagingControl.isEnabled = true;
				pagingControl.activate(resultPages);
			}
			
			// display initial results
			displayFirstResultsPage();
		}
		
		private function displayFirstResultsPage():void
		{
			var firstResultPageCollection:Array = AppModel.rawBookmarkListCollectionPager.first();
			// update current result page 'pointer'
			AppModel.currentResultPage = AppModel.rawBookmarkListCollectionPager.current();
			refreshListWithCollection(firstResultPageCollection);
		}
		
		private function displayNextResultsPage():void
		{
			var nextResultPageCollection:Array = AppModel.rawBookmarkListCollectionPager.next();
			// update current result page 'pointer'
			AppModel.currentResultPage = AppModel.rawBookmarkListCollectionPager.current();
			refreshListWithCollection(nextResultPageCollection);
		}
		
		private function displayPreviousResultsPage():void
		{
			var nextResultPageCollection:Array = AppModel.rawBookmarkListCollectionPager.previous();
			// update current result page 'pointer'
			AppModel.currentResultPage = AppModel.rawBookmarkListCollectionPager.current();
			refreshListWithCollection(nextResultPageCollection);
		}
		
		private function refreshListWithCollection(array:Array):void
		{
			cleanBookmarkList();
			AppModel.bookmarksList = PinboardService.mapRawBookmarksToBookmarks(array);
			activateBookmarkList();
		}		
		
		private function removeBookmarkFromList(bookmark:BookMark):void {
			
			var preDeleteScrollPos:Number = list.verticalScrollPosition;
			var bmIndex:Number = list.dataProvider.getItemIndex(bookmark);
			list.dataProvider.removeItemAt(bmIndex);
		}
		
		private function input_enterHandler():void
		{
			trace('entered search key word');
		}
		
		public function get onLoginScreenRequest():ISignal
		{
			return _onLoginScreenRequest;
		}
		
		private function createGUI():void
		{
			// create nice background
			this.addChild(_backgroundImage);
			
			// add a panel with a header, footer and no scroll shit
			this.panel.verticalScrollPolicy = Panel.SCROLL_POLICY_OFF;
			this.panel.horizontalScrollPolicy = Panel.SCROLL_POLICY_OFF;
			this.panel.nameList.add(PinboredDesktopTheme.PANEL_TRANSPARENT_BACKGROUND);
			
			this.panel.headerFactory = function():PinboredHeader
			{
				// const header:Header = new Header();
				const header:PinboredHeader = new PinboredHeader();
				header.title = "Bookmarks list";
				header.titleAlign = Header.TITLE_ALIGN_PREFER_LEFT;
				header.padding = 0;
				header.paddingLeft = 10;
				header.gap = 0;
				
				header.titleFactory = function():ITextRenderer
				{
					var titleRenderer:TextFieldTextRenderer = new TextFieldTextRenderer();
					titleRenderer.textFormat = PinboredDesktopTheme.TEXTFORMAT_SCREEN_TITLE;
					return titleRenderer;
				}
				
				const searchBookmarks:TextInput = new TextInput();
				searchBookmarks.nameList.add(PinboredDesktopTheme.TEXTINPUT_SEARCH);
				searchBookmarks.prompt = "search any keyword and hit enter...";
				searchBookmarks.width = 500;
				
				//we can't get an enter key event without changing the returnKeyLabel
				//not using ReturnKeyLabel.GO here so that it will build for web
				searchBookmarks.textEditorProperties.returnKeyLabel = "go";
				searchBookmarks.addEventListener(FeathersEventType.ENTER, input_enterHandler);
				
				header.rightItems = new <DisplayObject>[searchBookmarks];
				_panelExcludedSpace += header.height;
				
				return header;
			}
				
			// panel footer
			panel.footerFactory = function():ScrollContainer
			{ 
				var container:ScrollContainer = new ScrollContainer();
				container.nameList.add( ScrollContainer.ALTERNATE_NAME_TOOLBAR );
				container.horizontalScrollPolicy = ScrollContainer.SCROLL_POLICY_OFF;
				container.verticalScrollPolicy = ScrollContainer.SCROLL_POLICY_OFF;
								
				// create logo
				var alpha:Number = 0.3;
				
				// create left horizontal layoutgroup
				var leftItems:LayoutGroup = new LayoutGroup();
				var leftItemsLayout:HorizontalLayout = new HorizontalLayout();
				leftItemsLayout.paddingTop = leftItemsLayout.paddingRight = leftItemsLayout.paddingBottom = leftItemsLayout.paddingLeft = 14;
				leftItemsLayout.gap = 10;
				leftItems.layout = leftItemsLayout;
				leftItems.layoutData = new AnchorLayoutData(0, NaN, 0, 0, NaN, 0);
				
				// create logo
				var logo:Image = new Image(Texture.fromBitmap(new PinboredDesktopTheme.LOGO_TRANSPARENT(), true));
				logo.scaleX = logo.scaleY = 0.75;
				logo.alpha = alpha;
				leftItems.addChild(logo);
				
				// create disclaimer text
				var disclaimer:Label = new Label();
				disclaimer.maxWidth = 400;
				disclaimer.nameList.add(PinboredDesktopTheme.LABEL_DISCLAIMER);
				disclaimer.text = AppModel.DISCLAIMER_TEXT;
				leftItems.addChild(disclaimer);
				
				// create right horizontal layoutgroup
				var rightItems:LayoutGroup = new LayoutGroup();
				var rightItemsLayout:HorizontalLayout = new HorizontalLayout();
				rightItemsLayout.paddingTop = rightItemsLayout.paddingRight = rightItemsLayout.paddingBottom = rightItemsLayout.paddingLeft = 14;
				rightItemsLayout.gap = 10;
				rightItems.layout = rightItemsLayout;
				rightItems.layoutData = new AnchorLayoutData(0, 0, 0, NaN, NaN, 0);
				
				// create starling, feathers, open source icons
				var feathersLogo:Image = new Image(Texture.fromBitmap(new PinboredDesktopTheme.ICON_FEATHERS(), true));
				feathersLogo.scaleX = feathersLogo.scaleY = 0.8;
				feathersLogo.alpha = alpha;
				rightItems.addChild(feathersLogo);
				
				var starlingLogo:Image = new Image(Texture.fromBitmap(new PinboredDesktopTheme.ICON_STARLING(), true));
				starlingLogo.scaleX = starlingLogo.scaleY = 0.15;
				starlingLogo.alpha = alpha + 0.1;
				rightItems.addChild(starlingLogo);
				
				// create open source + link text container
				var rightTextGroup:LayoutGroup = new LayoutGroup();
				var rightTextGroupLayout:VerticalLayout = new VerticalLayout();
				rightTextGroupLayout.horizontalAlign = VerticalLayout.HORIZONTAL_ALIGN_RIGHT;
				rightTextGroupLayout.verticalAlign = VerticalLayout.VERTICAL_ALIGN_TOP;
				rightTextGroup.layout = rightTextGroupLayout;
				
				// create open source text
				var opensourceText:Label = new Label();
				opensourceText.isQuickHitAreaEnabled = false;
				opensourceText.nameList.add(PinboredDesktopTheme.LABEL_RIGHT_ALIGNED_TEXT);
				opensourceText.text = AppModel.OPENSOURCE_TEXT;
				rightTextGroup.addChild(opensourceText);
				
				// create author link text
				var authorlinkText:Label = new Label();
				authorlinkText.isQuickHitAreaEnabled = false;
				authorlinkText.nameList.add(PinboredDesktopTheme.LABEL_AUTHOR_LINK);
				authorlinkText.text = AppModel.LINK_TEXT;
				rightTextGroup.addChild(authorlinkText);
				
				// add text on the right to the right items layoutgroup
				rightItems.addChild(rightTextGroup);
				
				// add the left AND right items to the container
				container.addChild(leftItems);
				container.addChild(rightItems);
				
				// update _panelExcludedSpace
				_panelExcludedSpace += Math.max(container.height, leftItems.height, rightItems.height);
				
				return container;
			}
				
			this.panel.padding = 0;
			this.addChild(panel);
				
			// create screen layout (vertical unit)
			var panelLayout:VerticalLayout = new VerticalLayout();
			panelLayout.gap = 0;
			panelLayout.padding = 0;
			this.panel.layout = panelLayout;
			
			// add the tag search 'bar'
			this.searchTags = new TagTextInput(this._dpiScale);
			this.searchTags.width = this.width;
			this.panel.addChild(this.searchTags);
			
			// add the list result paging bar, initially set to invisible
			this.pagingControl = new Pager();
			this.pagingControl.visible = false;
			this.panel.addChild(this.pagingControl);
			
			// add a scrollcontainer for the list
			this.listScrollContainer = new ScrollContainer();
			this.listScrollContainer.verticalScrollPolicy = ScrollContainer.SCROLL_POLICY_ON;
			
			this.panel.addChild(this.listScrollContainer);
			
			// list styling
			var listLayout:VerticalLayout = new VerticalLayout();
			listLayout.hasVariableItemDimensions = true;
			
			// copied over from list initialize function
			listLayout.useVirtualLayout = true;
			listLayout.manageVisibility = true;
			listLayout.paddingTop = listLayout.paddingRight = listLayout.paddingBottom = listLayout.paddingLeft = 0;
			listLayout.gap = 0;
			listLayout.horizontalAlign = VerticalLayout.HORIZONTAL_ALIGN_JUSTIFY;
			listLayout.verticalAlign = VerticalLayout.VERTICAL_ALIGN_TOP;
			
			// assign the listLayout to the list
			this.list.layout = listLayout;
			
			// add a list for the bookmarks
			this.list.itemRendererFactory = function():IListItemRenderer
			{
				var renderer:PinboardLayoutGroupItemRenderer = new PinboardLayoutGroupItemRenderer();
				renderer.padding = 5;
				return renderer;
			};
			
			this.list.isSelectable = false;
			
			// add list to panel
			this.listScrollContainer.addChild(list);
			var listBg:Quad = new Quad(50, 50, 0x000000);
			listBg.alpha = 0.3;
			this.list.backgroundSkin = this.list.backgroundDisabledSkin = listBg;
			
			// finally, validate panel for scroll container height update
			this.panel.validate();
		}
		
		override protected function draw():void
		{
			// commit 
			
			// measurement
			panel.width = AppModel.starling.stage.stageWidth;
			panel.height = AppModel.starling.stage.stageHeight;
			
			_backgroundImage.width = this.width;
			_backgroundImage.height = this.height;
			
			// update screengroup, searchtags, scrollcontainer, list width etc.
			list.width = panel.width;
			listScrollContainer.width = panel.width;
			searchTags.width = panel.width;
			
			// update scrollcontainer height
			this.listScrollContainer.height = panel.height - _panelExcludedSpace - searchTags.height - 123;
			
			// layout
		}

	}
}