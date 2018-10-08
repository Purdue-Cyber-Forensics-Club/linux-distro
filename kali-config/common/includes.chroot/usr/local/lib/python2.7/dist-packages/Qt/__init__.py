# -*- coding: utf-8 -*-

# Copyright (c) 2009-2011 Christopher S. Case and David H. Bronke
# Licensed under the MIT license; see the LICENSE file for details.

"""Qt compatibility wrapper

Detects either PySide or PyQt.

"""
import sys
import logging

__all__ = [
        'QtCore', 'QtGui', 'QtNetwork', 'QtWebKit', 'QtUiTools', 'Signal',
        'Slot', 'loadUI'
        ]

QtCore = None
QtGui = None
QtNetwork = None
QtWebKit = None
QtUiTools = None
Signal = None
Slot = None
loadUI = None

binding = ""


logger = logging.getLogger("Qt")

def initialize(prefer="pyside", args=[]):
    if prefer is not None:
        prefer = prefer.lower()

    remainingArgs = list()
    for arg in args:
        if arg in ["--use-pyqt", "--use-pyqt4"]:
            prefer = "pyqt"
        elif arg == "--use-pyside":
            prefer = "pyside"
        else:
            remainingArgs.append(arg)

    if prefer in ["pyqt", "pyqt4"]:
        if not importPyQt():
            logger.warn("PyQt4 requested, but not installed.")

            if not importPySide():
                logger.error("Couldn't import PySide or PyQt4! You must have "
                        + "one or the other to run this app.")
                sys.exit(1)
    else:
        if not importPySide():
            logger.warn("PyQt4 requested, but not installed.")

            if not importPyQt():
                logger.error("Couldn't import PySide or PyQt4! You must have "
                        + "one or the other to run this app.")
                sys.exit(1)

    if len(remainingArgs) > 0:
        return remainingArgs


uiLoader = None


def importPySide():
    global QtCore, QtGui, QtNetwork, QtWebKit, QtUiTools, Signal, Slot, loadUI, binding

    try:
        from PySide import QtCore, QtGui, QtNetwork, QtWebKit, QtUiTools
        from PySide.QtCore import Signal, Slot

        class UiLoader(QtUiTools.QUiLoader):
            def __init__(self):
                super(UiLoader, self).__init__()
                self.rootWidget = None

            def createWidget(self, className, parent=None, name=''):
                widget = super(UiLoader, self).createWidget(
                        className, parent, name)

                if self.rootWidget is None:
                    self.rootWidget = widget
                else:
                    setattr(self.rootWidget, name, widget)

                if parent is not None:
                    setattr(parent, name, widget)
                else:
                    # Sadly, we can't reparent it to self, since QUiLoader
                    # isn't a QWidget.
                    logger.error("No parent specified! This will probably "
                            "crash due to C++ object deletion.")

                return widget

            def load(self, fileOrName, parentWidget=None):
                if self.rootWidget is not None:
                    logger.error("UiLoader already started loading a widget! "
                            "Aborting.")
                    return None

                widget = super(UiLoader, self).load(fileOrName, parentWidget)

                if widget != self.rootWidget:
                    logger.error("Returned widget isn't the root widget... "
                            "LOLWUT?")

                self.rootWidget = None
                return widget

        def loadUI(uiFilename, parent=None):
            global uiLoader
            if uiLoader is None:
                uiLoader = UiLoader()

            uiFile = QtCore.QFile(uiFilename, None)
            if not uiFile.open(QtCore.QIODevice.ReadOnly):
                logger.error("Couldn't open file %r!", uiFilename)
                return None

            try:
                return uiLoader.load(uiFile, parent)

            except:
                logger.exception("Exception loading UI from %r!", uiFilename)

            return None

        logger.info("Successfully initialized PySide.")

        binding = "PySide"
        return True

    except ImportError:
        return False


def importPyQt():
    global QtCore, QtGui, QtNetwork, QtWebKit, QtUiTools, Signal, Slot, loadUI, binding

    try:
        import sip
        sip.setapi('QString', 2)
        sip.setapi('QVariant', 2)

        from PyQt4 import QtCore, QtGui, QtNetwork, QtWebKit, uic
        from PyQt4.QtCore import pyqtSignal as Signal, pyqtSlot as Slot
        QtUiTools = object()

        def loadUI(uiFilename, parent=None):
            newWidget = uic.loadUi(uiFilename)
            newWidget.setParent(parent)
            return newWidget

        logger.info("Successfully initialized PyQt4.")

        binding = "PyQt4"
        return True

    except ImportError:
        return False

def isPySide():
    if binding == "PySide":
        return True

    return False

def isPyQt4():
    if binding == "PyQt4":
        return True

    return False
